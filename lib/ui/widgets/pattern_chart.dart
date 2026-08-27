import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/glucose_stats.dart';
import '../../util/formatting.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// Ambulatory-glucose-profile style view: every day in the window collapsed
/// onto a single 24-hour axis, showing the median line inside a 10th–90th
/// percentile band. Recurring patterns — overnight lows, the dawn rise,
/// post-meal spikes — stand out here in a way they cannot on a raw trace.
class PatternChart extends StatelessWidget {
  const PatternChart({
    super.key,
    required this.buckets,
    required this.unit,
    required this.range,
  });

  final List<HourlyBucket> buckets;
  final GlucoseUnit unit;
  final TargetRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final populated = buckets.where((b) => b.count > 0).toList();

    if (populated.length < 2) {
      return Center(
        child: Text(
          'Not enough data to show a daily pattern.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }

    FlSpot spot(HourlyBucket b, double mgdl) =>
        FlSpot(b.hour.toDouble(), unit.fromMgdl(mgdl));

    final medianSpots = [for (final b in populated) spot(b, b.median)];
    final lowSpots = [for (final b in populated) spot(b, b.p10)];
    final highSpots = [for (final b in populated) spot(b, b.p90)];

    final allMgdl = [
      for (final b in populated) ...[b.p10, b.p90],
      range.lowMgdl.toDouble(),
      range.highMgdl.toDouble(),
    ];
    final minY = unit.fromMgdl(allMgdl.reduce((a, b) => a < b ? a : b) - 20);
    final maxY = unit.fromMgdl(allMgdl.reduce((a, b) => a > b ? a : b) + 20);
    final gridStepMgdl = unit == GlucoseUnit.mgdl ? 50.0 : kMgdlPerMmol * 2;

    LineChartBarData band(List<FlSpot> spots) => LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          barWidth: 1,
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
          dotData: const FlDotData(show: false),
        );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 23,
        minY: minY < 0 ? 0 : minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            HorizontalRangeAnnotation(
              y1: unit.fromMgdl(range.lowMgdl),
              y2: unit.fromMgdl(range.highMgdl),
              color: GlucoseColors.inRange.withValues(alpha: 0.12),
            ),
          ],
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: unit.fromMgdl(gridStepMgdl),
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: unit.fromMgdl(gridStepMgdl),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  unit == GlucoseUnit.mgdl
                      ? value.round().toString()
                      : value.toStringAsFixed(1),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 6,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(formatHour(value.toInt()),
                    style: theme.textTheme.labelSmall),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (touched) => [
              for (final s in touched)
                if (s.barIndex == 2)
                  LineTooltipItem(
                    'Median ${unit.format(unit.toMgdl(s.y), withUnit: true)}\n'
                    'at ${formatHour(s.x.toInt())}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  )
                else
                  // fl_chart requires one entry per touched bar; the band lines
                  // themselves have nothing useful to say.
                  null,
            ],
          ),
        ),
        // Order matters: the two band edges are drawn first so `betweenBarsData`
        // can fill between indices 0 and 1, with the median on top.
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 0,
            toIndex: 1,
            color: theme.colorScheme.primary.withValues(alpha: 0.18),
          ),
        ],
        lineBarsData: [
          band(lowSpots),
          band(highSpots),
          LineChartBarData(
            spots: medianSpots,
            isCurved: true,
            curveSmoothness: 0.2,
            barWidth: 3,
            color: theme.colorScheme.primary,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
