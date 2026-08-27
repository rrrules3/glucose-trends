import 'package:flutter/material.dart';

import '../../models/glucose_stats.dart';
import '../../util/formatting.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// Stacked bar showing the share of readings below, inside and above target.
class TimeInRangeBar extends StatelessWidget {
  const TimeInRangeBar({
    super.key,
    required this.stats,
    required this.unit,
    required this.range,
  });

  final GlucoseStats stats;
  final GlucoseUnit unit;
  final TargetRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (stats.isEmpty) return const SizedBox.shrink();

    final segments = <(String, double, Color)>[
      ('Below', stats.timeBelowFraction, GlucoseColors.low),
      ('In range', stats.timeInRangeFraction, GlucoseColors.inRange),
      ('Above', stats.timeAboveFraction, GlucoseColors.high),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Time in range', style: theme.textTheme.titleSmall),
                Text(
                  '${unit.format(range.lowMgdl)}–'
                  '${unit.format(range.highMgdl, withUnit: true)}',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  // Childless ColoredBoxes size to zero under the default
                  // centre alignment; stretch makes them fill the bar height.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (_, fraction, color) in segments)
                      if (fraction > 0)
                        Expanded(
                          // Integer flex needs whole numbers; per-mille keeps
                          // thin slivers from collapsing to zero width.
                          flex: (fraction * 1000).round().clamp(1, 1000),
                          child: ColoredBox(color: color),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final (label, fraction, color) in segments)
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$label ${formatPercent(fraction)}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
