import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/headache_log_viewmodel.dart';
import '../widgets/daily_stats_card.dart';
import '../widgets/intensity_selector.dart';
import '../widgets/log_pain_button.dart';
import '../widgets/recent_entries_list.dart';

class HeadLogHomeScreen extends ConsumerWidget {
  const HeadLogHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<HeadacheLogState>>(headacheLogViewModelProvider, (
      previous,
      next,
    ) {
      if (next.hasError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: ${next.error}')),
        );
      }
    });

    final stateAsync = ref.watch(headacheLogViewModelProvider);

    return Scaffold(
      body: SafeArea(
        child: stateAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(headacheLogViewModelProvider),
          ),
          data: (state) {
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(headacheLogViewModelProvider),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    sliver: SliverList.list(
                      children: [
                        Text(
                          'HeadLog',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fast headache tracking built for one-tap repeats.',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                        LogPainButton(
                          intensity: state.selectedIntensity,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(headacheLogViewModelProvider.notifier)
                                .logEntry();
                          },
                        ),
                        const SizedBox(height: 18),
                        IntensitySelector(
                          selectedValue: state.selectedIntensity,
                          onSelected: (value) => ref
                              .read(headacheLogViewModelProvider.notifier)
                              .selectIntensity(value),
                        ),
                        const SizedBox(height: 18),
                        DailyStatsCard(dailyCounts: state.dailyCounts),
                        const SizedBox(height: 18),
                        RecentEntriesList(
                          entries: state.entries,
                          onDelete: (id) => ref
                              .read(headacheLogViewModelProvider.notifier)
                              .deleteEntry(id),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            state.pendingWrites > 0
                                ? 'Saving ${state.pendingWrites} entr${state.pendingWrites == 1 ? 'y' : 'ies'}...'
                                : 'All changes saved locally.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load your log.',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
