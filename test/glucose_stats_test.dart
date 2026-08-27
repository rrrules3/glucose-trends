import 'package:glucose_trends/models/glucose_reading.dart';
import 'package:glucose_trends/models/glucose_stats.dart';
import 'package:glucose_trends/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseReading r(int minutesFromStart, int mgdl) => GlucoseReading(
      time: DateTime(2024, 5, 1).add(Duration(minutes: minutesFromStart)),
      valueMgdl: mgdl,
    );

void main() {
  const range = TargetRange();

  group('GlucoseStats', () {
    test('reports the extreme readings with their timestamps', () {
      final stats = GlucoseStats.from(
        [r(0, 120), r(5, 62), r(10, 240), r(15, 130)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );

      expect(stats.minReading!.valueMgdl, 62);
      expect(stats.minReading!.time, DateTime(2024, 5, 1, 0, 5));
      expect(stats.maxReading!.valueMgdl, 240);
      expect(stats.maxReading!.time, DateTime(2024, 5, 1, 0, 10));
    });

    test('finds extremes regardless of input order', () {
      final ascending = GlucoseStats.from(
        [r(0, 80), r(5, 100), r(10, 200)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );
      final shuffled = GlucoseStats.from(
        [r(10, 200), r(0, 80), r(5, 100)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );

      expect(shuffled.minReading!.valueMgdl, ascending.minReading!.valueMgdl);
      expect(shuffled.maxReading!.valueMgdl, ascending.maxReading!.valueMgdl);
    });

    test('computes mean and sample standard deviation', () {
      final stats = GlucoseStats.from(
        [r(0, 100), r(5, 100), r(10, 130), r(15, 70)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );

      expect(stats.meanMgdl, 100);
      // Sample SD of [100,100,130,70] is sqrt(1800/3) ≈ 24.49.
      expect(stats.standardDeviation, closeTo(24.494, 0.001));
    });

    test('classifies time in range against the target thresholds', () {
      final stats = GlucoseStats.from(
        [r(0, 60), r(5, 120), r(10, 150), r(15, 250)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );

      expect(stats.timeBelowFraction, 0.25);
      expect(stats.timeInRangeFraction, 0.5);
      expect(stats.timeAboveFraction, 0.25);
    });

    test('boundary values count as in range', () {
      final stats = GlucoseStats.from(
        [r(0, 70), r(5, 180)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );
      expect(stats.timeInRangeFraction, 1.0);
    });

    test('respects a customised target range', () {
      final readings = [r(0, 85), r(5, 150)];
      final tight = GlucoseStats.from(
        readings,
        range: const TargetRange(lowMgdl: 90, highMgdl: 140),
        windowSpan: const Duration(hours: 1),
      );

      expect(tight.timeBelowFraction, 0.5);
      expect(tight.timeAboveFraction, 0.5);
      expect(tight.timeInRangeFraction, 0);
    });

    test('is empty-safe', () {
      final stats = GlucoseStats.from(
        const [],
        range: range,
        windowSpan: const Duration(hours: 1),
      );
      expect(stats.isEmpty, isTrue);
      expect(stats.minReading, isNull);
    });

    test('flags GMI as unreliable below 14 days', () {
      final short = GlucoseStats.from([r(0, 120)],
          range: range, windowSpan: const Duration(days: 7));
      final long = GlucoseStats.from([r(0, 120)],
          range: range, windowSpan: const Duration(days: 30));

      expect(short.gmiIsReliable, isFalse);
      expect(long.gmiIsReliable, isTrue);
    });

    test('sensor coverage compares reading count to the 5-minute cadence', () {
      // 12 readings over an hour is a complete hour at 5-minute spacing.
      final full = GlucoseStats.from(
        [for (var i = 0; i < 12; i++) r(i * 5, 110)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );
      expect(full.sensorCoverage, closeTo(1.0, 0.001));

      final half = GlucoseStats.from(
        [for (var i = 0; i < 6; i++) r(i * 5, 110)],
        range: range,
        windowSpan: const Duration(hours: 1),
      );
      expect(half.sensorCoverage, closeTo(0.5, 0.001));
    });
  });

  group('hourlyPattern', () {
    test('buckets readings by hour of day across multiple days', () {
      final readings = [
        GlucoseReading(time: DateTime(2024, 5, 1, 3), valueMgdl: 100),
        GlucoseReading(time: DateTime(2024, 5, 2, 3), valueMgdl: 200),
        GlucoseReading(time: DateTime(2024, 5, 3, 3), valueMgdl: 150),
      ];

      final buckets = hourlyPattern(readings);
      expect(buckets, hasLength(24));
      expect(buckets[3].count, 3);
      expect(buckets[3].median, 150);
      expect(buckets[4].count, 0);
    });

    test('percentile band widens with spread', () {
      final readings = [
        for (var v = 100; v <= 200; v += 10)
          GlucoseReading(time: DateTime(2024, 5, 1, 8), valueMgdl: v),
      ];
      final bucket = hourlyPattern(readings)[8];

      expect(bucket.median, closeTo(150, 0.001));
      expect(bucket.p10, lessThan(bucket.median));
      expect(bucket.p90, greaterThan(bucket.median));
    });
  });

  group('GlucoseUnit', () {
    test('round-trips between mg/dL and mmol/L', () {
      expect(GlucoseUnit.mmoll.fromMgdl(180), closeTo(9.99, 0.01));
      expect(GlucoseUnit.mmoll.toMgdl(5.5).round(), 99);
      expect(GlucoseUnit.mgdl.fromMgdl(120), 120);
    });

    test('formats with the conventional precision for each unit', () {
      expect(GlucoseUnit.mgdl.format(120.4), '120');
      expect(GlucoseUnit.mmoll.format(120), '6.7');
      expect(GlucoseUnit.mmoll.format(120, withUnit: true), '6.7 mmol/L');
    });
  });
}
