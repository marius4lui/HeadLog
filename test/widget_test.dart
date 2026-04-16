import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headlog/app.dart';
import 'package:headlog/models/daily_headache_stat.dart';
import 'package:headlog/models/headache_entry.dart';
import 'package:headlog/services/headache_database.dart';

class _FakeHeadacheDatabase extends HeadacheDatabase {
  @override
  Future<List<HeadacheEntry>> fetchRecentEntries({int limit = 30}) async {
    return const [];
  }

  @override
  Future<List<DailyHeadacheStat>> fetchDailyCounts({int days = 7}) async {
    return const [];
  }

  @override
  Future<void> insertEntry(HeadacheEntry entry) async {}

  @override
  Future<void> deleteEntry(String id) async {}
}

void main() {
  testWidgets('HeadLog home screen renders core UI', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          headacheDatabaseProvider.overrideWithValue(_FakeHeadacheDatabase()),
        ],
        child: const HeadLogApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Instant Log'), findsOneWidget);
    expect(find.text('New Log'), findsOneWidget);
  });
}
