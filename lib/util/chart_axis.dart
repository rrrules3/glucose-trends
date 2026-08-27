import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

/// True when an interval tick sits too close to one of the axis-end labels.
///
/// fl_chart labels both ends of an axis in addition to the interval ticks.
/// Ticks fall on absolute boundaries — midnight, a whole hour — so one
/// routinely lands a few minutes from an end label and the two render on top of
/// each other.
///
/// Measured in pixels, not as a fraction of the axis: a percentage rule has no
/// idea how wide a label actually is, and gets it wrong at the boundary. A
/// 24-hour window starting at 18:01 puts the first 6-hourly tick 8.3% along,
/// which slipped past an 8% threshold and drew "6 PM" over "8 PM".
bool collidesWithAxisEnd(
  double value,
  TitleMeta meta, {
  /// Enough for the widest label these axes produce ("12 AM", "Aug 24"), plus
  /// breathing room either side.
  double minGapPx = 62.0,
}) {
  if (value == meta.min || value == meta.max) return false;

  final span = meta.max - meta.min;
  if (span <= 0 || meta.parentAxisSize <= 0) return false;

  final pxPerUnit = meta.parentAxisSize / span;
  return (value - meta.min) * pxPerUnit < minGapPx ||
      (meta.max - value) * pxPerUnit < minGapPx;
}


/// Pick four labels spread evenly across [xs], snapped to values that exist.
///
/// Returns indices into [xs]. Use this when the values are not contiguous — a
/// run of days with holes in it — so labels stay visually even along the axis
/// while still landing on real data. Fewer than four come back when snapping
/// lands twice on the same point.
List<int> quarterPositions(List<int> xs) {
  if (xs.length <= 4) return [for (var i = 0; i < xs.length; i++) i];

  final first = xs.first;
  final span = xs.last - first;
  final picks = <int>{};

  for (var q = 0; q < 4; q++) {
    final target = first + (span * q / 3).round();
    var best = 0;
    var bestDistance = (xs[0] - target).abs();
    for (var i = 1; i < xs.length; i++) {
      final distance = (xs[i] - target).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = i;
      }
    }
    picks.add(best);
  }

  return picks.toList()..sort();
}

/// Pick four evenly spread positions across [count] items, always including
/// the first and last.
///
/// Returns fewer than four when there are fewer than four items. Indices, not
/// timestamps: a chart plotted per day must put its labels *on* days, and a
/// literal quarter of a seven-day span lands at 08:00 on day three — the label
/// reads "19" while the mark sits eight hours right of the 19th's own point.
List<int> quarterIndices(int count) {
  if (count <= 0) return const [];
  if (count <= 4) return [for (var i = 0; i < count; i++) i];
  final last = count - 1;
  return [
    0,
    (last / 3).round(),
    (last * 2 / 3).round(),
    last,
  ];
}

/// Label a sequence of dates, naming the month only where it changes.
///
/// `Aug 17 · 19 · 21 · 24` inside one month; `Jul 25 · Aug 4 · 14 · 24` across
/// a boundary. Repeating the month on every tick is noise — the reader needs it
/// once at the start, and again wherever it actually turns over.
List<String> monthAwareDateLabels(List<DateTime> dates) => [
      for (var i = 0; i < dates.length; i++)
        DateFormat(
          i == 0 ||
                  dates[i - 1].month != dates[i].month ||
                  dates[i - 1].year != dates[i].year
              ? 'MMM d'
              : 'd',
        ).format(dates[i]),
    ];
