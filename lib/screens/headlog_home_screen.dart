import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app.dart';
import '../models/headache_entry.dart';
import '../viewmodels/headache_log_viewmodel.dart';
import '../widgets/recent_entries_list.dart';

const _causeOptions = <_CauseOption>[
  _CauseOption(id: 'stress', label: 'Stress', emoji: '💼'),
  _CauseOption(id: 'sleep', label: 'Sleep', emoji: '😴'),
  _CauseOption(id: 'screen', label: 'Screen', emoji: '💻'),
  _CauseOption(id: 'water', label: 'Water', emoji: '💧'),
  _CauseOption(id: 'weather', label: 'Weather', emoji: '☁️'),
];

class HeadLogHomeScreen extends ConsumerStatefulWidget {
  const HeadLogHomeScreen({super.key});

  @override
  ConsumerState<HeadLogHomeScreen> createState() => _HeadLogHomeScreenState();
}

class _HeadLogHomeScreenState extends ConsumerState<HeadLogHomeScreen> {
  String _view = 'week';
  DateTime _selectedDate = DateTime.now();
  bool _sheetExpanded = true;
  int? _composerIntensity;
  final Set<String> _composerCauses = <String>{};
  final TextEditingController _composerNoteController = TextEditingController();

  @override
  void dispose() {
    _composerNoteController.dispose();
    super.dispose();
  }

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
          final selectedEntries = _entriesForDay(state.entries, _selectedDate);
          final composerHeight = (MediaQuery.sizeOf(context).height * 0.7)
              .clamp(430.0, 640.0);
          final collapsedHeight = 96.0;

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
                      padding: EdgeInsets.fromLTRB(
                        24,
                        16,
                        24,
                        (_sheetExpanded ? composerHeight : collapsedHeight) +
                            24,
                      ),
                      sliver: SliverList.list(
                        children: [
                          _Header(isDark: isDark, onThemeToggle: _toggleTheme),
                          const SizedBox(height: 24),
                          _CalendarCard(
                            currentView: _view,
                            selectedDate: _selectedDate,
                            entries: state.entries,
                            dayEntries: selectedEntries,
                            onViewChanged: (value) =>
                                setState(() => _view = value),
                            onDateSelected: (value) =>
                                setState(() => _selectedDate = value),
                          ),
                          const SizedBox(height: 24),
                          _QuickLogCard(
                            intensity: state.selectedIntensity,
                            onTap: () async {
                              HapticFeedback.mediumImpact();
                              await ref
                                  .read(headacheLogViewModelProvider.notifier)
                                  .logEntry();
                            },
                          ),
                          const SizedBox(height: 18),
                          _QuickIntensityRow(
                            selectedValue: state.selectedIntensity,
                            onSelected: (value) => ref
                                .read(headacheLogViewModelProvider.notifier)
                                .selectIntensity(value),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Entries',
                                style: theme.textTheme.labelMedium?.copyWith(
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
                            entries: selectedEntries,
                            onDelete: (id) => ref
                                .read(headacheLogViewModelProvider.notifier)
                                .deleteEntry(id),
                            onTap: _openEntryDetails,
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
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: _ComposerSheet(
                    expanded: _sheetExpanded,
                    selectedIntensity: _composerIntensity,
                    selectedCauses: _composerCauses,
                    noteController: _composerNoteController,
                    height: composerHeight,
                    collapsedHeight: collapsedHeight,
                    onExpand: () => setState(() => _sheetExpanded = true),
                    onCollapse: () => setState(() => _sheetExpanded = false),
                    onIntensitySelected: (value) {
                      setState(() => _composerIntensity = value);
                    },
                    onCauseToggled: (value) {
                      setState(() {
                        if (_composerCauses.contains(value)) {
                          _composerCauses.remove(value);
                        } else {
                          _composerCauses.add(value);
                        }
                      });
                    },
                    onSave: () async {
                      final intensity = _composerIntensity;
                      if (intensity == null) {
                        return;
                      }

                      HapticFeedback.mediumImpact();
                      await ref
                          .read(headacheLogViewModelProvider.notifier)
                          .createEntry(
                            intensity: intensity,
                            causes: _composerCauses.toList(growable: false),
                            note: _composerNoteController.text,
                          );

                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        _selectedDate = DateTime.now();
                      });
                      _resetComposer();
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<HeadacheEntry> _entriesForDay(
    List<HeadacheEntry> entries,
    DateTime day,
  ) {
    return entries
        .where((entry) => DateUtils.isSameDay(entry.timestamp, day))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  void _resetComposer() {
    setState(() {
      _composerIntensity = null;
      _composerCauses.clear();
      _composerNoteController.clear();
      _sheetExpanded = true;
    });
  }

  void _toggleTheme() {
    final next = ref.read(themeModeProvider) == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    ref.read(themeModeProvider.notifier).state = next;
  }

  Future<void> _openEntryDetails(HeadacheEntry entry) async {
    final edited = await showModalBottomSheet<HeadacheEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EntryDetailsSheet(entry: entry),
    );

    if (edited != null) {
      await ref.read(headacheLogViewModelProvider.notifier).updateEntry(edited);
    }
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
    required this.dayEntries,
    required this.onViewChanged,
    required this.onDateSelected,
  });

  final String currentView;
  final DateTime selectedDate;
  final List<HeadacheEntry> entries;
  final List<HeadacheEntry> dayEntries;
  final ValueChanged<String> onViewChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avgIntensity = dayEntries.isEmpty
        ? 0.0
        : dayEntries.map((entry) => entry.intensity).reduce((a, b) => a + b) /
              dayEntries.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          _SegmentedControl(active: currentView, onChange: onViewChanged),
          const SizedBox(height: 28),
          _WeekStrip(
            selectedDate: selectedDate,
            entries: entries,
            onSelect: onDateSelected,
          ),
          const SizedBox(height: 20),
          _DayMiniCard(
            selectedDate: selectedDate,
            entries: dayEntries,
            averageIntensity: avgIntensity,
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

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selectedDate,
    required this.entries,
    required this.onSelect,
  });

  final DateTime selectedDate;
  final List<HeadacheEntry> entries;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
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
  });

  final DateTime day;
  final bool isSelected;
  final bool hasEntry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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

class _DayMiniCard extends StatelessWidget {
  const _DayMiniCard({
    required this.selectedDate,
    required this.entries,
    required this.averageIntensity,
  });

  final DateTime selectedDate;
  final List<HeadacheEntry> entries;
  final double averageIntensity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topCauses = <String, int>{};
    for (final entry in entries) {
      for (final cause in entry.causes) {
        topCauses[cause] = (topCauses[cause] ?? 0) + 1;
      }
    }
    final leadingCause = topCauses.entries.isEmpty
        ? null
        : (topCauses.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(selectedDate),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entries.isEmpty
                ? 'No logged headaches on this day.'
                : '${entries.length} logs • avg intensity ${averageIntensity.toStringAsFixed(1)}/10',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (leadingCause != null) ...[
            const SizedBox(height: 10),
            Text(
              'Likely trigger: $leadingCause',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
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
    required this.selectedCauses,
    required this.noteController,
    required this.height,
    required this.collapsedHeight,
    required this.onExpand,
    required this.onCollapse,
    required this.onIntensitySelected,
    required this.onCauseToggled,
    required this.onSave,
  });

  final bool expanded;
  final int? selectedIntensity;
  final Set<String> selectedCauses;
  final TextEditingController noteController;
  final double height;
  final double collapsedHeight;
  final VoidCallback onExpand;
  final VoidCallback onCollapse;
  final ValueChanged<int> onIntensitySelected;
  final ValueChanged<String> onCauseToggled;
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
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      height: expanded ? height : collapsedHeight,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 48,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, expanded ? 20 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 8 && expanded) {
                  onCollapse();
                } else if (details.delta.dy < -8 && !expanded) {
                  onExpand();
                }
              },
              onTap: expanded ? null : onExpand,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: expanded ? 18 : 8),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      width: expanded ? 64 : 56,
                      height: expanded ? 7 : 6,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    SizedBox(height: expanded ? 14 : 8),
                    Text(
                      'New Log',
                      style:
                          (expanded
                                  ? theme.textTheme.headlineSmall
                                  : theme.textTheme.titleMedium)
                              ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: expanded ? 8 : 4),
            if (expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.9,
                            ),
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options[index];
                          final selected = selectedIntensity == option.value;
                          return GestureDetector(
                            onTap: () => onIntensitySelected(option.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(26),
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
                                  const SizedBox(height: 10),
                                  Text(
                                    option.label,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: selected
                                              ? theme.colorScheme.surface
                                              : theme.colorScheme.outline,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11,
                                        ),
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Possible cause',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final cause in _causeOptions)
                          _CauseChip(
                            option: cause,
                            selected: selectedCauses.contains(cause.id),
                            onTap: () => onCauseToggled(cause.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Additional info',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: noteController,
                        maxLines: null,
                        expands: true,
                        decoration: InputDecoration(
                          hintText:
                              'Coffee, too little sleep, stress, aura, medication...',
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerLow,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: selectedIntensity == null ? null : onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.onSurface,
                          foregroundColor: theme.colorScheme.surface,
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
            if (!expanded)
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 22,
                            color: theme.colorScheme.surface,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedIntensity == null
                                ? 'Add detailed entry'
                                : 'Intensity $selectedIntensity/10 selected',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: theme.colorScheme.outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryDetailsSheet extends StatefulWidget {
  const _EntryDetailsSheet({required this.entry});

  final HeadacheEntry entry;

  @override
  State<_EntryDetailsSheet> createState() => _EntryDetailsSheetState();
}

class _EntryDetailsSheetState extends State<_EntryDetailsSheet> {
  late int _intensity = widget.entry.intensity;
  late final Set<String> _causes = widget.entry.causes.toSet();
  late final TextEditingController _noteController = TextEditingController(
    text: widget.entry.note ?? '',
  );

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Entry details',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  DateFormat(
                    'EEE, d MMM • HH:mm',
                  ).format(widget.entry.timestamp),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Slider(
              value: _intensity.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_intensity',
              onChanged: (value) {
                setState(() => _intensity = value.round());
              },
            ),
            Text(
              'Intensity $_intensity/10',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Possible cause',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final cause in _causeOptions)
                  _CauseChip(
                    option: cause,
                    selected: _causes.contains(cause.id),
                    onTap: () {
                      setState(() {
                        if (_causes.contains(cause.id)) {
                          _causes.remove(cause.id);
                        } else {
                          _causes.add(cause.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Add more context for this headache...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    widget.entry.copyWith(
                      intensity: _intensity,
                      causes: _causes.toList(growable: false),
                      note: _noteController.text.trim(),
                    ),
                  );
                },
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CauseChip extends StatelessWidget {
  const _CauseChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _CauseOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          '${option.emoji} ${option.label}',
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
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

class _CauseOption {
  const _CauseOption({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
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
