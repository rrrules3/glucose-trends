import 'package:flutter/material.dart';

import '../../models/glucose_reading.dart';
import '../../util/formatting.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// The most recent reading, its trend arrow and how stale it is.
class CurrentReadingCard extends StatelessWidget {
  const CurrentReadingCard({
    super.key,
    required this.reading,
    required this.unit,
    required this.range,
    required this.sourceLabel,
  });

  final GlucoseReading? reading;
  final GlucoseUnit unit;
  final TargetRange range;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = reading;

    if (r == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.sensors_off_rounded),
          title: const Text('No readings loaded'),
          subtitle: const Text('Connect Dexcom or import a Clarity export.'),
          titleTextStyle: theme.textTheme.titleMedium,
        ),
      );
    }

    final color = GlucoseColors.forValue(r.valueMgdl, range);
    // A G7 reports every 5 minutes; past ~20 the number is no longer "current".
    final isStale =
        DateTime.now().difference(r.time) > const Duration(minutes: 20);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              color.withValues(alpha: 0.20),
              color.withValues(alpha: 0.03),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isStale ? 'LAST READING' : 'CURRENT',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      unit.format(r.valueMgdl),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(unit.label, style: theme.textTheme.labelMedium),
                    const SizedBox(width: 8),
                    Text(
                      r.trend.arrow,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: color, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${GlucoseColors.describe(r.valueMgdl, range)} · '
                  '${r.trend.label}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatRelative(r.time),
                    style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Chip(
                  label: Text(sourceLabel),
                  visualDensity: VisualDensity.compact,
                  labelStyle: theme.textTheme.labelSmall,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
