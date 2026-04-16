import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models/headache_entry.dart';
import '../viewmodels/headache_log_viewmodel.dart';
import '../widgets/recent_entries_list.dart';

class HeadLogHomeScreen extends ConsumerStatefulWidget {
  const HeadLogHomeScreen({super.key});

  @override
  ConsumerState<HeadLogHomeScreen> createState() => _HeadLogHomeScreenState();
}

class _HeadLogHomeScreenState extends ConsumerState<HeadLogHomeScreen> {
  String _view = 'week';
  bool _sheetExpanded = false;
  int? _composerIntensity;
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
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
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(headacheLogViewModelProvider),
        ),
        data: (state) {
          final dayEntries =
              state.entries
                  .where(
                    (entry) =>
                        DateUtils.isSameDay(entry.timestamp, _selectedDate),
                  )
                  .toList()
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          return LayoutBuilder(
            builder: (context, constraints) {
              final collapsedBottom = MediaQuery.paddingOf(context).bottom + 16;
              final expandedHeight = constraints.maxHeight * 0.62;

              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          theme.colorScheme.surfaceContainerLowest,
                        ],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 180),
                          sliver: SliverList.list(
                            children: [
                              _Header(
                                isDark: isDark,
                                onThemeToggle: _toggleTheme,
                              ),
                              const SizedBox(height: 24),
                              _CalendarCard(
                                currentView: _view,
                                selectedDate: _selectedDate,
                                entries: state.entries,
                                onViewChanged: (value) {
                                  setState(() => _view = value);
                                },
                                onDateSelected: (value) {
                                  setState(() => _selectedDate = value);
                                },
                              ),
                              const SizedBox(height: 24),
                              _QuickLogCard(
                                intensity: state.selectedIntensity,
                                onTap: () async {
                                  HapticFeedback.mediumImpact();
                                  await ref
                                      .read(
                                        headacheLogViewModelProvider.notifier,
                                      )
                                      .logEntry();
                                },
                              ),
                              const SizedBox(height: 18),
                              _QuickIntensityRow(
                                selectedValue: state.selectedIntensity,
                                onSelected: (value) {
                                  ref
                                      .read(
                                        headacheLogViewModelProvider.notifier,
                                      )
                                      .selectIntensity(value);
                                },
                              ),
                              const SizedBox(height: 28),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Entries',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.8,
                                          color: theme.colorScheme.outline,
                                        ),
                                  ),
                                  Icon(
                                    Icons.trending_up_rounded,
                                    size: 18,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              RecentEntriesList(
                                entries: dayEntries,
                                onDelete: (id) {
                                  ref
                                      .read(
                                        headacheLogViewModelProvider.notifier,
                                      )
                                      .deleteEntry(id);
                                },
                                emptyLabel: 'No headaches logged for this day.',
                              ),
                              const SizedBox(height: 20),
                              Text(
                                state.pendingWrites > 0
                                    ? 'Saving ${state.pendingWrites} entries locally...'
                                    : 'Everything is saved on device.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_sheetExpanded)
                    GestureDetector(
                      onTap: () => setState(() => _sheetExpanded = false),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: _sheetExpanded ? 1 : 0,
                        child: Container(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.52)
                              : Colors.white.withValues(alpha: 0.58),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutCubic,
                    left: 0,
                    right: 0,
                    bottom: _sheetExpanded ? 0 : collapsedBottom,
                    child: SafeArea(
                      top: false,
                      child: _ComposerSheet(
                        expanded: _sheetExpanded,
                        selectedIntensity: _composerIntensity,
                        height: expandedHeight,
                        onToggle: () {
                          setState(() => _sheetExpanded = !_sheetExpanded);
                        },
                        onIntensitySelected: (value) {
                          setState(() => _composerIntensity = value);
                        },
                        onSave: () async {
                          final intensity = _composerIntensity;
                          if (intensity == null) {
                            return;
                          }

                          HapticFeedback.mediumImpact();
                          await ref
                              .read(headacheLogViewModelProvider.notifier)
                              .logEntryWithIntensity(intensity);

                          if (!mounted) {
                            return;
                          }

                          setState(() {
                            _composerIntensity = null;
                            _sheetExpanded = false;
                            _selectedDate = DateTime.now();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _toggleTheme() {
    final next = ref.read(themeModeProvider) == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    ref.read(themeModeProvider.notifier).state = next;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onThemeToggle});

  final bool isDark;
  final VoidCallback onThemeToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JOURNAL',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Overview',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -1.2,
              ),
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: IconButton(
            onPressed: onThemeToggle,
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.currentView,
    required this.selectedDate,
    required this.entries,
    required this.onViewChanged,
    required this.onDateSelected,
  });

  final String currentView;
  final DateTime selectedDate;
  final List<HeadacheEntry> entries;
  final ValueChanged<String> onViewChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          _SegmentedControl(active: currentView, onChange: onViewChanged),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: switch (currentView) {
              'day' => _CenteredLabel(
                key: const ValueKey('day'),
                label: DateFormat('EEEE, d MMM').format(selectedDate),
              ),
              'month' => _CenteredLabel(
                key: const ValueKey('month'),
                label: DateFormat('MMMM yyyy').format(selectedDate),
              ),
              _ => _WeekStrip(
                key: const ValueKey('week'),
                selectedDate: selectedDate,
                entries: entries,
                onSelect: onDateSelected,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _SegmentedControl extends StatelessWidget {
  const _SegmentedControl({required this.active, required this.onChange});

  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const options = <String>['day', 'week', 'month'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChange(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active == option ? theme.colorScheme.surface : null,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: active == option
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    option.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: active == option
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CenteredLabel extends StatelessWidget {
  const _CenteredLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    super.key,
    required this.selectedDate,
    required this.entries,
    required this.onSelect,
  });

  final DateTime selectedDate;
  final List<HeadacheEntry> entries;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = selectedDate.subtract(const Duration(days: 3));
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(start.year, start.month, start.day + index),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final day in days)
          _WeekDayPill(
            day: day,
            isSelected: DateUtils.isSameDay(day, selectedDate),
            hasEntry: entries.any(
              (entry) => DateUtils.isSameDay(entry.timestamp, day),
            ),
            onTap: () => onSelect(day),
            colorScheme: theme.colorScheme,
          ),
      ],
    );
  }
}

class _WeekDayPill extends StatelessWidget {
  const _WeekDayPill({
    required this.day,
    required this.isSelected,
    required this.hasEntry,
    required this.onTap,
    required this.colorScheme,
  });

  final DateTime day;
  final bool isSelected;
  final bool hasEntry;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isSelected ? 1.06 : 1,
        child: Opacity(
          opacity: isSelected ? 1 : 0.5,
          child: Column(
            children: [
              Text(
                DateFormat('E').format(day).substring(0, 1).toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.onSurface
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isSelected
                        ? colorScheme.surface
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: hasEntry ? colorScheme.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickLogCard extends StatelessWidget {
  const _QuickLogCard({required this.intensity, required this.onTap});

  final int intensity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.onSurface,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 32,
                  color: theme.colorScheme.surface,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instant Log',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.surface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap once or repeatedly. Current intensity $intensity/10.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.surface.withValues(
                          alpha: 0.74,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickIntensityRow extends StatelessWidget {
  const _QuickIntensityRow({
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const options = <_IntensityOption>[
      _IntensityOption(label: 'Light', value: 3, color: Color(0xFF10B981)),
      _IntensityOption(label: 'Medium', value: 5, color: Color(0xFFF59E0B)),
      _IntensityOption(label: 'Strong', value: 8, color: Color(0xFFF97316)),
    ];
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var i = 0; i < options.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == options.length - 1 ? 0 : 12),
              child: GestureDetector(
                onTap: () => onSelected(options[i].value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selectedValue == options[i].value
                        ? theme.colorScheme.surface
                        : theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selectedValue == options[i].value
                          ? Colors.transparent
                          : theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                    ),
                    boxShadow: selectedValue == options[i].value
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: options[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        options[i].label,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ComposerSheet extends StatelessWidget {
  const _ComposerSheet({
    required this.expanded,
    required this.selectedIntensity,
    required this.height,
    required this.onToggle,
    required this.onIntensitySelected,
    required this.onSave,
  });

  final bool expanded;
  final int? selectedIntensity;
  final double height;
  final VoidCallback onToggle;
  final ValueChanged<int> onIntensitySelected;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const options = <_IntensityOption>[
      _IntensityOption(label: 'Light', value: 3, color: Color(0xFF10B981)),
      _IntensityOption(label: 'Medium', value: 5, color: Color(0xFFF59E0B)),
      _IntensityOption(label: 'Strong', value: 8, color: Color(0xFFF97316)),
      _IntensityOption(label: 'Extreme', value: 10, color: Color(0xFFE11D48)),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      height: expanded ? height : 108,
      margin: EdgeInsets.symmetric(horizontal: expanded ? 0 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(expanded ? 40 : 32),
          topRight: Radius.circular(expanded ? 40 : 32),
          bottomLeft: Radius.circular(expanded ? 0 : 32),
          bottomRight: Radius.circular(expanded ? 0 : 32),
        ),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Column(
                children: [
                  Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (!expanded)
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 30,
                            color: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Add entry',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (expanded)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'New Log',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: onToggle,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.78,
                          ),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = selectedIntensity == option.value;

                        return GestureDetector(
                          onTap: () => onIntensitySelected(option.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              color: selected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: selected
                                    ? Colors.transparent
                                    : theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.28),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: option.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: selected
                                        ? theme.colorScheme.surface
                                        : theme.colorScheme.outline,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Quick save',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose an intensity and save a new entry instantly. This keeps the log fast while matching the demo composer style.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedIntensity == null ? null : onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface,
                          foregroundColor: theme.colorScheme.surface,
                          disabledBackgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          disabledForegroundColor: theme.colorScheme.outline,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'SAVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IntensityOption {
  const _IntensityOption({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
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
