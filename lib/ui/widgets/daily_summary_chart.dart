import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/glucose_stats.dart';
import '../../util/chart_axis.dart';
import '../../util/gaps.dart';
import '../../util/glucose_colors.dart';
import '../../util/units.dart';

/// One point per day: the day's average, inside a band spanning its low to its
/// high. Tapping a day pins its numbers open.
///
/// Used instead of the raw trace once the window covers a week or more, where
/// tens of thousands of readings stop being individually legible.
class DailySummaryChart extends StatefulWidget {
  const DailySummaryChart({
    super.key,
    required this.summaries,
    required this.unit,
    required this.range,
  });

  final List<DailySummary> summaries;
  final GlucoseUnit unit;
  final TargetRange range;

  /// A week is the point where per-day detail beats the raw trace.
  static const threshold = Duration(days: 7);

  @override
  State<DailySummaryChart> createState() => _DailySummaryChartState();
}

class _DailySummaryChartState extends State<DailySummaryChart> {
  /// Index of the day whose tooltip is pinned open.
  ///
  /// fl_chart's built-in tooltip only shows while a finger is down, so on a
  /// touchscreen a tap-and-release flashes it and leaves nothing behind.
  /// Tracking the selection here and feeding it back through
  /// `showingTooltipIndicators` keeps the numbers up after the tap.
  int? _selected;

  /// Index of the mean line within `lineBarsData`.
  static const _meanBarIndex = 2;

  @override
  void didUpdateWidget(DailySummaryChart old) {
    super.didUpdateWidget(old);
    // A different timeframe renumbers the spots; a stale index would pin the
    // wrong day, or point past the end.
    if (old.summaries.length != widget.summaries.length ||
        (old.summaries.isNotEmpty &&
            widget.summaries.isNotEmpty &&
            old.summaries.first.day != widget.summaries.first.day)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = widget.summaries;
    final unit = widget.unit;
    final range = widget.range;

    if (summaries.length < 2) {
      return Center(
        child: Text(
          'Not enough days in this timeframe.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }

    // Plotted against days elapsed since the first day — not list index, and
    // not a timestamp. Index would collapse a missing week into a single step,
    // drawing days as adjacent when they are not; timestamps would drift by an
    // hour across a daylight-saving change. Day offsets do neither, and still
    // put every tick exactly on a data point.
    final base = dayNumber(summaries.first.day);
    final offsets = [for (final s in summaries) dayNumber(s.day) - base];

    // Inserted null spots shift every later index, so the tooltip cannot look
    // straight into `summaries` any more. This maps a spot back to its day.
    final spotToSummary = <int?>[];
    for (var i = 0; i < summaries.length; i++) {
      if (i > 0 && offsets[i] - offsets[i - 1] > 1) spotToSummary.add(null);
      spotToSummary.add(i);
    }

    List<FlSpot> series(double Function(DailySummary) value) {
      final spots = <FlSpot>[];
      for (var i = 0; i < summaries.length; i++) {
        // A missing day breaks the line rather than being drawn through.
        if (i > 0 && offsets[i] - offsets[i - 1] > 1) {
          spots.add(FlSpot.nullSpot);
        }
        spots.add(FlSpot(offsets[i].toDouble(), value(summaries[i])));
      }
      return spots;
    }

    final lows = series((s) => unit.fromMgdl(s.min.valueMgdl));
    final highs = series((s) => unit.fromMgdl(s.max.valueMgdl));
    final means = series((s) => unit.fromMgdl(s.meanMgdl));

    // The four days that get a label and a gridline, snapped to days that
    // actually have readings.
    final labelledPositions = quarterPositions(offsets);
    final labelledDays = [for (final i in labelledPositions) offsets[i]];
    final labels = monthAwareDateLabels(
      [for (final i in labelledPositions) summaries[i].day],
    );

    final lastIndex = offsets.last.toDouble();
    // Inset the axis so the gridlines under the first and last labels fall
    // inside the plot instead of on its boundary, where they are invisible.
    final inset = (lastIndex * 0.03).clamp(0.3, 4.0);

    // fl_chart also emits ticks at the padded bounds, which round to the same
    // index as the first and last days and would double their labels and
    // gridlines. Only whole indices are real days.
    bool isDay(double v) => (v - v.roundToDouble()).abs() < 0.01;

    final allMgdl = <double>[
      for (final s in summaries) ...[
        s.min.valueMgdl.toDouble(),
        s.max.valueMgdl.toDouble(),
      ],
      range.lowMgdl.toDouble(),
      range.highMgdl.toDouble(),
    ];
    final minY = unit.fromMgdl(allMgdl.reduce((a, b) => a < b ? a : b) - 15);
    final maxY = unit.fromMgdl(allMgdl.reduce((a, b) => a > b ? a : b) + 15);
    final gridStepMgdl = unit == GlucoseUnit.mgdl ? 50.0 : kMgdlPerMmol * 2;

    LineChartBarData edge(List<FlSpot> spots) => LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          barWidth: 1,
          color: theme.colorScheme.primary.withValues(alpha: 0.30),
          dotData: const FlDotData(show: false),
        );

    final meanBar = LineChartBarData(
      spots: means,
      isCurved: true,
      curveSmoothness: 0.2,
      barWidth: 3,
      color: theme.colorScheme.primary,
      // Draws the indicator line beneath the pinned day.
      showingIndicators: [?_selected],
      dotData: FlDotData(
        // Dots read as "one point per day"; past a month they merge into a line.
        show: summaries.length <= 32,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: index == _selected ? 5 : 3,
          color: GlucoseColors.forValue(unit.toMgdl(spot.y).round(), range),
          strokeWidth: index == _selected ? 2.5 : 1.5,
          strokeColor: theme.colorScheme.surface,
        ),
      ),
    );

    return LineChart(
      LineChartData(
        minX: -inset,
        maxX: lastIndex + inset,
        // Ticks step one day at a time from the first; the label callback then
        // draws only the four chosen ones.
        baselineX: 0,
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
          horizontalInterval: unit.fromMgdl(gridStepMgdl),
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.35),
            strokeWidth: 1,
          ),
          // A faint vertical rule under each labelled day, so a point can be
          // traced back to its date without guessing.
          verticalInterval: 1,
          checkToShowVerticalLine: (v) =>
              isDay(v) && labelledDays.contains(v.round()),
          getDrawingVerticalLine: (_) => FlLine(
            color: theme.colorScheme.outline.withValues(alpha: 0.28),
            strokeWidth: 1,
            dashArray: const [4, 4],
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
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (!isDay(value)) return const SizedBox.shrink();
                final position = labelledDays.indexOf(value.round());
                if (position < 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  // Off by default in fl_chart, which lets the label centred on
                  // the last point overhang the chart and get clipped.
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(
                    labels[position],
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          // LineChart overwrites `showingTooltipIndicators` with its own
          // internal list whenever this is left on, which silently discards a
          // pinned selection. Owning the interaction is the only way to keep a
          // tooltip up after the finger lifts.
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            // Only settle the selection when the gesture ends, so dragging
            // across the chart previews days without committing to one.
            if (event is! FlTapUpEvent &&
                event is! FlPanEndEvent &&
                event is! FlLongPressEnd) {
              return;
            }
            final touched = response?.lineBarSpots;
            final index = (touched == null || touched.isEmpty)
                ? null
                : touched.first.spotIndex;
            if (index != _selected) setState(() => _selected = index);
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            getTooltipColor: (_) => theme.colorScheme.inverseSurface,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                // fl_chart wants one entry per touched bar; only the mean line
                // carries the summary, so the band edges return null.
                if (spot.barIndex == _meanBarIndex &&
                    spot.spotIndex < spotToSummary.length &&
                    spotToSummary[spot.spotIndex] != null)
                  _tooltipFor(summaries[spotToSummary[spot.spotIndex]!], theme)
                else
                  null,
            ],
          ),
        ),
        showingTooltipIndicators: [
          if (_selected != null && _selected! < means.length)
            ShowingTooltipIndicators([
              LineBarSpot(meanBar, _meanBarIndex, meanBar.spots[_selected!]),
            ]),
        ],
        // Order matters: the band edges come first so `betweenBarsData` can
        // fill between indices 0 and 1, with the mean on top at index 2.
        betweenBarsData: [
          BetweenBarsData(
            fromIndex: 0,
            toIndex: 1,
            color: theme.colorScheme.primary.withValues(alpha: 0.16),
          ),
        ],
        lineBarsData: [edge(lows), edge(highs), meanBar],
      ),
    );
  }

  LineTooltipItem _tooltipFor(DailySummary s, ThemeData theme) {
    final unit = widget.unit;
    final range = widget.range;
    final onInverse = theme.colorScheme.onInverseSurface;
    TextStyle line(Color c) =>
        TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600);

    return LineTooltipItem(
      DateFormat('EEE, MMM d').format(s.day),
      TextStyle(color: onInverse, fontWeight: FontWeight.w700, fontSize: 12),
      children: [
        TextSpan(
          text: '\nAvg ${unit.format(s.meanMgdl, withUnit: true)}',
          style: TextStyle(color: onInverse, fontSize: 12),
        ),
        TextSpan(
          text: '\nHigh ${unit.format(s.max.valueMgdl)}'
              '  ·  ${DateFormat.jm().format(s.max.time)}',
          style: line(GlucoseColors.forValue(s.max.valueMgdl, range)),
        ),
        TextSpan(
          text: '\nLow  ${unit.format(s.min.valueMgdl)}'
              '  ·  ${DateFormat.jm().format(s.min.time)}',
          style: line(GlucoseColors.forValue(s.min.valueMgdl, range)),
        ),
      ],
    );
  }

}
