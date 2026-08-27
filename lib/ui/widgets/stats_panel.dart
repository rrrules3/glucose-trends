import 'package:flutter/material.dart';

import '../../models/glucose_stats.dart';
import '../../util/formatting.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// Headline numbers for the chosen timeframe, with the lowest and highest
/// readings given top billing and stamped with when they happened.
class StatsPanel extends StatelessWidget {
  const StatsPanel({
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

    if (stats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No readings in this timeframe.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ),
      );
    }

    final min = stats.minReading!;
    final max = stats.maxReading!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ExtremeCard(
                title: 'Lowest',
                icon: Icons.south_rounded,
                valueText: unit.format(min.valueMgdl),
                unitText: unit.label,
                timeText: formatReadingTime(min.time, stats.windowSpan),
                color: GlucoseColors.forValue(min.valueMgdl, range),
                statusText: GlucoseColors.describe(min.valueMgdl, range),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ExtremeCard(
                title: 'Highest',
                icon: Icons.north_rounded,
                valueText: unit.format(max.valueMgdl),
                unitText: unit.label,
                timeText: formatReadingTime(max.time, stats.windowSpan),
                color: GlucoseColors.forValue(max.valueMgdl, range),
                statusText: GlucoseColors.describe(max.valueMgdl, range),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (stats.sensorCoverage < 0.7) ...[
          _CoverageWarning(coverage: stats.sensorCoverage),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 18,
              children: [
                _MiniStat(
                  label: 'Average',
                  value: unit.format(stats.meanMgdl),
                  suffix: unit.label,
                ),
                _MiniStat(
                  label: 'Std dev',
                  value: unit.format(stats.standardDeviation),
                  suffix: unit.label,
                ),
                _MiniStat(
                  label: 'Variability',
                  value: stats.coefficientOfVariation.toStringAsFixed(0),
                  suffix: '% CV',
                  // ≤36% is the consensus target for stable glucose.
                  emphasis: stats.coefficientOfVariation <= 36
                      ? GlucoseColors.inRange
                      : GlucoseColors.high,
                ),
                _MiniStat(
                  label: 'GMI (est. A1c)',
                  value: stats.gmiPercent.toStringAsFixed(1),
                  suffix: '%',
                  footnote: stats.gmiIsReliable ? null : 'needs 14+ days',
                ),
                _MiniStat(
                  label: 'Readings',
                  value: stats.count.toString(),
                  suffix:
                      '${(stats.sensorCoverage * 100).round()}% coverage',
                  // Statistics over a patchy window are drawn from whatever
                  // happens to be there, and read just as confidently as a
                  // complete one. Colour the coverage figure when it is low.
                  emphasis: stats.sensorCoverage < 0.7
                      ? GlucoseColors.high
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown when much of the window has no readings at all.
///
/// Every figure on this screen is computed only from readings that exist, so a
/// window that is half empty produces an average, a time-in-range and a
/// highest/lowest that look exactly as authoritative as a complete one. Saying
/// so is the difference between a summary and a misleading one.
class _CoverageWarning extends StatelessWidget {
  const _CoverageWarning({required this.coverage});

  final double coverage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GlucoseColors.high.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlucoseColors.high.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: GlucoseColors.high),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only ${(coverage * 100).round()}% of this timeframe has '
              'readings. These figures cover the data that exists, not the '
              'whole period.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtremeCard extends StatelessWidget {
  const _ExtremeCard({
    required this.title,
    required this.icon,
    required this.valueText,
    required this.unitText,
    required this.timeText,
    required this.color,
    required this.statusText,
  });

  final String title;
  final IconData icon;
  final String valueText;
  final String unitText;
  final String timeText;
  final Color color;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.04),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      title.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          valueText,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(unitText, style: theme.textTheme.labelSmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(statusText,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: color, fontWeight: FontWeight.w600)),
                Text(
                  timeText,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.suffix,
    this.emphasis,
    this.footnote,
  });

  final String label;
  final String value;
  final String? suffix;
  final Color? emphasis;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: emphasis,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (suffix != null)
            Text(
              suffix!,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          if (footnote != null)
            Text(
              footnote!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
