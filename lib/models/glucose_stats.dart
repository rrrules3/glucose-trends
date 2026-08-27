import 'dart:math' as math;

import 'glucose_reading.dart';
import '../util/units.dart';

/// Summary statistics for a set of readings inside a chosen timeframe.
///
/// All glucose figures are mg/dL; the UI converts for display.
class GlucoseStats {
  const GlucoseStats({
    required this.count,
    required this.minReading,
    required this.maxReading,
    required this.meanMgdl,
    required this.standardDeviation,
    required this.timeInRangeFraction,
    required this.timeBelowFraction,
    required this.timeAboveFraction,
    required this.windowSpan,
  });

  final int count;

  /// The single lowest reading in the window, with its timestamp — so the UI
  /// can tell the user *when* the low happened, not just how low it was.
  final GlucoseReading? minReading;
  final GlucoseReading? maxReading;

  final double meanMgdl;
  final double standardDeviation;

  final double timeInRangeFraction;
  final double timeBelowFraction;
  final double timeAboveFraction;

  final Duration windowSpan;

  bool get isEmpty => count == 0;

  /// Coefficient of variation — the standard measure of glucose variability.
  /// Consensus target is ≤36%.
  double get coefficientOfVariation =>
      meanMgdl == 0 ? 0 : (standardDeviation / meanMgdl) * 100;

  /// Glucose Management Indicator: an A1c estimate from mean glucose.
  /// Formula from Bergenstal et al. (2018). Only meaningful over ≥14 days.
  double get gmiPercent => 3.31 + 0.02392 * meanMgdl;

  bool get gmiIsReliable => windowSpan >= const Duration(days: 14);

  /// Fraction of the window actually covered by readings, assuming the G7's
  /// 5-minute cadence. Low coverage means the stats are based on partial data.
  double get sensorCoverage {
    final expected = windowSpan.inMinutes / 5;
    if (expected <= 0) return 0;
    return math.min(1.0, count / expected);
  }

  static const empty = GlucoseStats(
    count: 0,
    minReading: null,
    maxReading: null,
    meanMgdl: 0,
    standardDeviation: 0,
    timeInRangeFraction: 0,
    timeBelowFraction: 0,
    timeAboveFraction: 0,
    windowSpan: Duration.zero,
  );

  /// Compute stats over [readings], which need not be sorted.
  factory GlucoseStats.from(
    Iterable<GlucoseReading> readings, {
    required TargetRange range,
    required Duration windowSpan,
  }) {
    final list = readings.toList();
    if (list.isEmpty) return empty;

    GlucoseReading min = list.first;
    GlucoseReading max = list.first;
    var sum = 0.0;
    var below = 0, inRange = 0, above = 0;

    for (final r in list) {
      if (r.valueMgdl < min.valueMgdl) min = r;
      if (r.valueMgdl > max.valueMgdl) max = r;
      sum += r.valueMgdl;
      if (r.valueMgdl < range.lowMgdl) {
        below++;
      } else if (r.valueMgdl > range.highMgdl) {
        above++;
      } else {
        inRange++;
      }
    }

    final mean = sum / list.length;
    var sqDiff = 0.0;
    for (final r in list) {
      final d = r.valueMgdl - mean;
      sqDiff += d * d;
    }
    // Sample standard deviation (n-1) matches how Clarity reports variability.
    final sd = list.length > 1 ? math.sqrt(sqDiff / (list.length - 1)) : 0.0;

    return GlucoseStats(
      count: list.length,
      minReading: min,
      maxReading: max,
      meanMgdl: mean,
      standardDeviation: sd,
      timeInRangeFraction: inRange / list.length,
      timeBelowFraction: below / list.length,
      timeAboveFraction: above / list.length,
      windowSpan: windowSpan,
    );
  }
}

/// One hour-of-day bucket used by the daily pattern (AGP-style) chart.
class HourlyBucket {
  const HourlyBucket({
    required this.hour,
    required this.median,
    required this.p10,
    required this.p90,
    required this.count,
  });

  final int hour;
  final double median;
  final double p10;
  final double p90;
  final int count;
}

/// Bucket readings by hour of day and compute a median band, revealing
/// recurring daily patterns (dawn phenomenon, post-meal spikes, overnight lows).
List<HourlyBucket> hourlyPattern(Iterable<GlucoseReading> readings) {
  final buckets = List.generate(24, (_) => <int>[]);
  for (final r in readings) {
    buckets[r.time.hour].add(r.valueMgdl);
  }

  return [
    for (var h = 0; h < 24; h++)
      if (buckets[h].isEmpty)
        HourlyBucket(hour: h, median: 0, p10: 0, p90: 0, count: 0)
      else
        () {
          final vals = buckets[h]..sort();
          return HourlyBucket(
            hour: h,
            median: _percentile(vals, 0.5),
            p10: _percentile(vals, 0.10),
            p90: _percentile(vals, 0.90),
            count: vals.length,
          );
        }(),
  ];
}

/// Linear-interpolated percentile over a pre-sorted list.
double _percentile(List<int> sorted, double p) {
  if (sorted.isEmpty) return 0;
  if (sorted.length == 1) return sorted.first.toDouble();
  final pos = p * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo].toDouble();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}


/// One calendar day condensed to the numbers worth seeing at a glance.
class DailySummary {
  const DailySummary({
    required this.day,
    required this.meanMgdl,
    required this.min,
    required this.max,
    required this.count,
  });

  /// Local midnight of the day being summarised.
  final DateTime day;

  final double meanMgdl;

  /// Kept as full readings so the UI can show *when* the extreme happened.
  final GlucoseReading min;
  final GlucoseReading max;

  final int count;

  /// Share of a full day's 5-minute readings actually present.
  double get coverage => (count / 288).clamp(0.0, 1.0);
}

/// Condense readings into one entry per calendar day, ascending.
///
/// Over a week or more a raw trace is tens of thousands of points squeezed
/// into a few hundred pixels, where individual days stop being legible. A mean
/// per day with its own high and low keeps the day-to-day story readable and
/// still surfaces the extremes, which is the whole point of the screen.
List<DailySummary> dailySummaries(Iterable<GlucoseReading> readings) {
  final byDay = <DateTime, List<GlucoseReading>>{};
  for (final r in readings) {
    final day = DateTime(r.time.year, r.time.month, r.time.day);
    (byDay[day] ??= <GlucoseReading>[]).add(r);
  }

  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days)
      () {
        final entries = byDay[day]!;
        var min = entries.first;
        var max = entries.first;
        var sum = 0.0;
        for (final r in entries) {
          if (r.valueMgdl < min.valueMgdl) min = r;
          if (r.valueMgdl > max.valueMgdl) max = r;
          sum += r.valueMgdl;
        }
        return DailySummary(
          day: day,
          meanMgdl: sum / entries.length,
          min: min,
          max: max,
          count: entries.length,
        );
      }(),
  ];
}
