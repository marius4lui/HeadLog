import 'package:flutter/material.dart';

class IntensityOption {
  const IntensityOption({
    required this.value,
    required this.emoji,
    required this.label,
  });

  final int value;
  final String emoji;
  final String label;
}

class IntensitySelector extends StatelessWidget {
  const IntensitySelector({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  final int selectedValue;
  final ValueChanged<int> onSelected;

  static const options = <IntensityOption>[
    IntensityOption(value: 3, emoji: '🙂', label: 'Light'),
    IntensityOption(value: 5, emoji: '😣', label: 'Medium'),
    IntensityOption(value: 8, emoji: '🤯', label: 'Strong'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        for (var index = 0; index < options.length; index++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: index == options.length - 1 ? 0 : 12,
              ),
              child: _IntensityChip(
                option: options[index],
                isSelected: options[index].value == selectedValue,
                onTap: () => onSelected(options[index].value),
                colorScheme: theme.colorScheme,
              ),
            ),
          ),
      ],
    );
  }
}

class _IntensityChip extends StatelessWidget {
  const _IntensityChip({
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  final IntensityOption option;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(option.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(
                option.label,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
