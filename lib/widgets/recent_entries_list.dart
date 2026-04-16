import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/headache_entry.dart';

class RecentEntriesList extends StatelessWidget {
  const RecentEntriesList({
    super.key,
    required this.entries,
    required this.onDelete,
    required this.emptyLabel,
  });

  final List<HeadacheEntry> entries;
  final ValueChanged<String> onDelete;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.monitor_heart_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < entries.length; index++)
          Padding(
            padding: EdgeInsets.only(
              bottom: index == entries.length - 1 ? 0 : 24,
            ),
            child: _TimelineEntry(
              entry: entries[index],
              showConnector: index != entries.length - 1,
              onDelete: onDelete,
            ),
          ),
      ],
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.showConnector,
    required this.onDelete,
  });

  final HeadacheEntry entry;
  final bool showConnector;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = _intensityStyle(
      entry.intensity,
      theme.colorScheme.brightness,
    );

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => onDelete(entry.id),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(entry.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                if (showConnector)
                  Container(width: 1, height: 64, color: theme.dividerColor),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: style.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Intensity ${entry.intensity}/10',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((entry.note ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(entry.note!, style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _IntensityStyle _intensityStyle(int intensity, Brightness brightness) {
    if (intensity <= 3) {
      return _IntensityStyle(
        label: 'Light',
        color: brightness == Brightness.dark
            ? const Color(0xFF34D399)
            : const Color(0xFF10B981),
      );
    }
    if (intensity <= 6) {
      return _IntensityStyle(
        label: 'Medium',
        color: brightness == Brightness.dark
            ? const Color(0xFFFBBF24)
            : const Color(0xFFF59E0B),
      );
    }
    return _IntensityStyle(
      label: 'Strong',
      color: brightness == Brightness.dark
          ? const Color(0xFFFB7185)
          : const Color(0xFFF97316),
    );
  }
}

class _IntensityStyle {
  const _IntensityStyle({required this.label, required this.color});

  final String label;
  final Color color;
}
