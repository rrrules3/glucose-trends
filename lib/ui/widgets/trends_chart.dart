import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/glucose_reading.dart';
import '../../models/time_range.dart';
import '../../util/chart_axis.dart';
import '../../util/downsample.dart';
import '../../util/gaps.dart';
import '../../util/formatting.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// Glucose over the selected window, with the target range shaded behind the
/// trace and the line coloured by how far each segment strays from it.
class TrendsChart extends StatelessWidget {
  const TrendsChart({
    super.key,
    required this.readings,
    required this.window,
    required this.unit,
    required this.range,
  });

  final List<GlucoseReading> readings;
  final DateWindow window;
  final GlucoseUnit unit;
  final TargetRange range;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (readings.isEmpty) {
      return _ChartPlaceholder(
        message: 'No readings in this timeframe.',
        theme: theme,
      );
    }

    final points = downsampleForChart(readings);
    // Break the trace wherever the sensor was not reporting, rather than
    // drawing a straight line across the missing stretch.
    final spots = spotsWithGapBreaks(
      points,
      (r) => FlSpot(
        r.time.millisecondsSinceEpoch.toDouble(),
        unit.fromMgdl(r.valueMgdl),
      ),
    );

    // Pad the y-axis around the data and the target band so neither is clipped.
    final values = points.map((r) => r.valueMgdl);
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    final minY = unit.fromMgdl(
        (dataMin < range.lowMgdl ? dataMin : range.lowMgdl) - 20);
    final maxY = unit.fromMgdl(
        (dataMax > range.highMgdl ? dataMax : range.highMgdl) + 20);

    final span = window.span;
    final gridStepMgdl = unit == GlucoseUnit.mgdl ? 50.0 : kMgdlPerMmol * 2;

    return LineChart(
      LineChartData(
        minX: window.start.millisecondsSinceEpoch.toDouble(),
        maxX: window.end.millisecondsSinceEpoch.toDouble(),
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
              reservedSize: 30,
              interval: _axisInterval(span),
              getTitlesWidget: (value, meta) {
                if (collidesWithAxisEnd(value, meta)) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    formatAxisLabel(
                      DateTime.fromMillisecondsSinceEpoch(value.toInt()),
                      span,
                    ),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${unit.format(unit.toMgdl(spot.y), withUnit: true)}\n'
                  '${formatReadingTime(DateTime.fromMillisecondsSinceEpoch(spot.x.toInt()), span)}',
                  TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            barWidth: 2,
            // Colour stops follow the value itself, so hypo and hyper stretches
            // are visible without reading the axis. The gradient must be keyed
            // to the whole chart rather than fl_chart's default box around the
            // line, or the stops would rescale to the data and mislabel every
            // in-range value near the bottom of the trace.
            gradientArea: LineChartGradientArea.wholeChart,
            gradient: _valueGradient(
              minY < 0 ? 0 : minY,
              maxY,
            ),
            dotData: FlDotData(
              // Individual dots would be noise on a long window, but on a short
              // one they show the true 5-minute sampling cadence.
              show: points.length <= 120,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 2.5,
                color: GlucoseColors.forValue(
                    unit.toMgdl(spot.y).round(), range),
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.16),
                  theme.colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A vertical gradient whose stops land on the low/high thresholds, which
  /// tints each part of the line by the zone it is passing through.
  LinearGradient _valueGradient(double minY, double maxY) {
    final lowY = unit.fromMgdl(range.lowMgdl);
    final highY = unit.fromMgdl(range.highMgdl);
    double stop(double y) =>
        ((y - minY) / (maxY - minY)).clamp(0.0, 1.0);

    // Gradient stops run bottom-to-top, so they are listed in reverse.
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: const [
        GlucoseColors.veryLow,
        GlucoseColors.low,
        GlucoseColors.inRange,
        GlucoseColors.inRange,
        GlucoseColors.high,
        GlucoseColors.veryHigh,
      ],
      stops: [
        0.0,
        stop(lowY) * 0.98,
        stop(lowY),
        stop(highY),
        (stop(highY) + 0.02).clamp(0.0, 1.0),
        1.0,
      ],
    );
  }

  static double _axisInterval(Duration span) {
    // Aim for roughly five labels regardless of how wide the window is.
    final ms = span.inMilliseconds / 5;
    const day = 86400000.0;
    const hour = 3600000.0;
    for (final candidate in [
      hour,
      3 * hour,
      6 * hour,
      12 * hour,
      day,
      2 * day,
      7 * day,
      14 * day,
      30 * day,
    ]) {
      if (ms <= candidate) return candidate;
    }
    return 30 * day;
  }
}

class _ChartPlaceholder extends StatelessWidget {
  const _ChartPlaceholder({required this.message, required this.theme});

  final String message;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
}
