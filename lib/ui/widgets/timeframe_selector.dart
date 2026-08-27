import 'package:flutter/material.dart';

import '../../models/time_range.dart';

/// Horizontal chip row for picking the window the whole screen is scoped to.
class TimeframeSelector extends StatelessWidget {
  const TimeframeSelector({
    super.key,
    required this.selectedLabel,
    required this.onSelected,
    required this.onCustomRequested,
  });

  final String selectedLabel;
  final ValueChanged<TimeframeOption> onSelected;
  final VoidCallback onCustomRequested;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TimeframeOption.presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = TimeframeOption.presets[i];
          final isCustom = option.duration == null;
          return ChoiceChip(
            label: Text(option.label),
            avatar: isCustom
                ? const Icon(Icons.date_range_rounded, size: 16)
                : null,
            selected: selectedLabel == option.label,
            onSelected: (_) =>
                isCustom ? onCustomRequested() : onSelected(option),
          );
        },
      ),
    );
  }
}
