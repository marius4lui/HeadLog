import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_headache_stat.dart';

class DailyStatsCard extends StatelessWidget {
  const DailyStatsCard({super.key, required this.dailyCounts});

  final List<DailyHeadacheStat> dailyCounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayCount =
        dailyCounts.isNotEmpty &&
            DateUtils.isSameDay(dailyCounts.first.dayStart, DateTime.now())
        ? dailyCounts.first.count
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Stats',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text('$todayCount logged today', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            if (dailyCounts.isEmpty)
              Text(
                'No entries yet. Your first tap starts the log.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: [
                  for (final stat in dailyCounts.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat.EEEE().format(stat.dayStart),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${stat.count}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
