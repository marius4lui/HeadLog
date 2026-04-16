import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/daily_headache_stat.dart';
import '../models/headache_entry.dart';
import '../services/headache_database.dart';

const _uuid = Uuid();

final headacheLogViewModelProvider =
    AsyncNotifierProvider<HeadacheLogViewModel, HeadacheLogState>(
      HeadacheLogViewModel.new,
    );

class HeadacheLogState {
  const HeadacheLogState({
    required this.selectedIntensity,
    required this.entries,
    required this.dailyCounts,
    this.pendingWrites = 0,
  });

  final int selectedIntensity;
  final List<HeadacheEntry> entries;
  final List<DailyHeadacheStat> dailyCounts;
  final int pendingWrites;

  HeadacheLogState copyWith({
    int? selectedIntensity,
    List<HeadacheEntry>? entries,
    List<DailyHeadacheStat>? dailyCounts,
    int? pendingWrites,
  }) {
    return HeadacheLogState(
      selectedIntensity: selectedIntensity ?? this.selectedIntensity,
      entries: entries ?? this.entries,
      dailyCounts: dailyCounts ?? this.dailyCounts,
      pendingWrites: pendingWrites ?? this.pendingWrites,
    );
  }
}

class HeadacheLogViewModel extends AsyncNotifier<HeadacheLogState> {
  HeadacheDatabase get _database => ref.read(headacheDatabaseProvider);

  @override
  Future<HeadacheLogState> build() async {
    final entries = await _database.fetchRecentEntries();
    final dailyCounts = await _database.fetchDailyCounts();

    return HeadacheLogState(
      selectedIntensity: 5,
      entries: entries,
      dailyCounts: dailyCounts,
    );
  }

  void selectIntensity(int intensity) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    state = AsyncData(current.copyWith(selectedIntensity: intensity));
  }

  Future<void> logEntry() async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    await logEntryWithIntensity(current.selectedIntensity);
  }

  Future<void> logEntryWithIntensity(int intensity) async {
    await createEntry(intensity: intensity);
  }

  Future<void> createEntry({
    required int intensity,
    List<String> causes = const <String>[],
    String? note,
  }) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final entry = HeadacheEntry(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      intensity: intensity,
      causes: causes,
      note: note?.trim().isEmpty ?? true ? null : note?.trim(),
    );

    state = AsyncData(
      current.copyWith(
        entries: [entry, ...current.entries],
        dailyCounts: _incrementDailyCount(current.dailyCounts, entry.timestamp),
        pendingWrites: current.pendingWrites + 1,
      ),
    );

    unawaited(_persistEntry(entry));
  }

  Future<void> updateEntry(HeadacheEntry updatedEntry) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final previousEntry = current.entries.cast<HeadacheEntry?>().firstWhere(
      (item) => item?.id == updatedEntry.id,
      orElse: () => null,
    );
    if (previousEntry == null) {
      return;
    }

    final updatedEntries =
        current.entries
            .map((entry) => entry.id == updatedEntry.id ? updatedEntry : entry)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    state = AsyncData(current.copyWith(entries: updatedEntries));

    try {
      await _database.insertEntry(updatedEntry);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(current);
    }
  }

  Future<void> deleteEntry(String id) async {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final entry = current.entries.cast<HeadacheEntry?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );
    if (entry == null) {
      return;
    }

    state = AsyncData(
      current.copyWith(
        entries: current.entries.where((item) => item.id != id).toList(),
        dailyCounts: _decrementDailyCount(current.dailyCounts, entry.timestamp),
      ),
    );

    try {
      await _database.deleteEntry(id);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      state = AsyncData(current);
    }
  }

  Future<void> _persistEntry(HeadacheEntry entry) async {
    try {
      await _database.insertEntry(entry);
      final latest = state.valueOrNull;
      if (latest == null) {
        return;
      }

      state = AsyncData(
        latest.copyWith(
          pendingWrites: latest.pendingWrites > 0
              ? latest.pendingWrites - 1
              : 0,
        ),
      );
    } catch (error, stackTrace) {
      final latest = state.valueOrNull;
      state = AsyncError(error, stackTrace);

      if (latest == null) {
        return;
      }

      state = AsyncData(
        latest.copyWith(
          entries: latest.entries.where((item) => item.id != entry.id).toList(),
          dailyCounts: _decrementDailyCount(
            latest.dailyCounts,
            entry.timestamp,
          ),
          pendingWrites: latest.pendingWrites > 0
              ? latest.pendingWrites - 1
              : 0,
        ),
      );
    }
  }

  List<DailyHeadacheStat> _incrementDailyCount(
    List<DailyHeadacheStat> stats,
    DateTime timestamp,
  ) {
    final key = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final updated = [...stats];
    final index = updated.indexWhere((item) => item.dayStart == key);

    if (index >= 0) {
      updated[index] = DailyHeadacheStat(
        dayStart: key,
        count: updated[index].count + 1,
      );
    } else {
      updated.insert(0, DailyHeadacheStat(dayStart: key, count: 1));
    }

    updated.sort((a, b) => b.dayStart.compareTo(a.dayStart));
    return updated.take(7).toList(growable: false);
  }

  List<DailyHeadacheStat> _decrementDailyCount(
    List<DailyHeadacheStat> stats,
    DateTime timestamp,
  ) {
    final key = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final updated = <DailyHeadacheStat>[];

    for (final stat in stats) {
      if (stat.dayStart != key) {
        updated.add(stat);
        continue;
      }

      final nextCount = stat.count - 1;
      if (nextCount > 0) {
        updated.add(
          DailyHeadacheStat(dayStart: stat.dayStart, count: nextCount),
        );
      }
    }

    return updated;
  }
}
