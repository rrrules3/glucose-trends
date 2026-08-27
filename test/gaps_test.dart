import 'package:fl_chart/fl_chart.dart';
import 'package:glucose_trends/models/glucose_reading.dart';
import 'package:glucose_trends/util/chart_axis.dart';
import 'package:glucose_trends/util/gaps.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseReading at(DateTime t, [int mgdl = 110]) =>
    GlucoseReading(time: t, valueMgdl: mgdl);

List<GlucoseReading> run(DateTime from, int count) => [
      for (var i = 0; i < count; i++)
        at(from.add(Duration(minutes: i * 5))),
    ];

void main() {
  final start = DateTime(2026, 8, 20, 8);

  group('spotsWithGapBreaks', () {
    FlSpot spot(GlucoseReading r) =>
        FlSpot(r.time.millisecondsSinceEpoch.toDouble(), r.valueMgdl.toDouble());

    test('leaves a continuous run unbroken', () {
      final spots = spotsWithGapBreaks(run(start, 12), spot);
      expect(spots, hasLength(12));
      expect(spots.any((s) => s == FlSpot.nullSpot), isFalse);
    });

    test('breaks the line across a real gap', () {
      // Two hours of readings, three hours of nothing, then more.
      final readings = [
        ...run(start, 24),
        ...run(start.add(const Duration(hours: 5)), 24),
      ];
      final spots = spotsWithGapBreaks(readings, spot);

      expect(spots.where((s) => s == FlSpot.nullSpot), hasLength(1));
      // The break sits between the two runs, not at either end.
      expect(spots.first, isNot(FlSpot.nullSpot));
      expect(spots.last, isNot(FlSpot.nullSpot));
      expect(spots.indexOf(FlSpot.nullSpot), 24);
    });

    test('tolerates a single missed reading without breaking', () {
      final readings = [
        at(start),
        at(start.add(const Duration(minutes: 10))), // one dropped
      ];
      expect(spotsWithGapBreaks(readings, spot), hasLength(2));
    });

    test('breaks once per gap, not once per missing reading', () {
      final readings = [
        ...run(start, 6),
        ...run(start.add(const Duration(days: 3)), 6),
      ];
      final spots = spotsWithGapBreaks(readings, spot);
      expect(spots.where((s) => s == FlSpot.nullSpot), hasLength(1));
    });

    test('is empty-safe', () {
      expect(spotsWithGapBreaks(const [], spot), isEmpty);
    });
  });

  group('missingSpan', () {
    final end = start.add(const Duration(hours: 6));

    test('reports nothing missing for a full window', () {
      // 6 hours at 5-minute spacing.
      expect(missingSpan(run(start, 72), start, end), Duration.zero);
    });

    test('counts an interior gap', () {
      final readings = [
        ...run(start, 12), // first hour
        ...run(start.add(const Duration(hours: 4)), 24), // last two
      ];
      final missing = missingSpan(readings, start, end);
      expect(missing.inMinutes, greaterThan(150));
    });

    test('counts missing time at the start and end of the window', () {
      final readings = run(start.add(const Duration(hours: 2)), 12);
      final missing = missingSpan(readings, start, end);
      // ~2 hours before and ~3 after.
      expect(missing.inHours, greaterThanOrEqualTo(4));
    });

    test('an empty window is entirely missing', () {
      expect(missingSpan(const [], start, end), end.difference(start));
    });
  });

  group('dayNumber', () {
    test('is stable across a daylight-saving boundary', () {
      // Consecutive calendar days must differ by exactly one, even where the
      // local day is 23 or 25 hours long.
      final a = dayNumber(DateTime(2026, 11, 1));
      final b = dayNumber(DateTime(2026, 11, 2));
      expect(b - a, 1);
    });

    test('ignores the time of day', () {
      expect(dayNumber(DateTime(2026, 8, 20, 0, 1)),
          dayNumber(DateTime(2026, 8, 20, 23, 59)));
    });

    test('counts real elapsed days across a gap', () {
      expect(dayNumber(DateTime(2026, 8, 27)) - dayNumber(DateTime(2026, 8, 20)),
          7);
    });
  });

  group('quarterPositions', () {
    test('spreads labels evenly when days are contiguous', () {
      final xs = [for (var i = 0; i < 8; i++) i];
      expect(quarterPositions(xs), [0, 2, 5, 7]);
    });

    test('snaps to days that exist rather than into a gap', () {
      // Days 0,1,2 then a jump to 20,21,22 — labels must land on real days.
      final xs = [0, 1, 2, 20, 21, 22];
      final picks = quarterPositions(xs);

      expect(picks.first, 0);
      expect(picks.last, xs.length - 1);
      for (final i in picks) {
        expect(i, inInclusiveRange(0, xs.length - 1));
      }
    });

    test('never returns duplicates', () {
      final xs = [0, 1, 30, 31];
      final picks = quarterPositions(xs);
      expect(picks.toSet(), hasLength(picks.length));
    });

    test('handles very short runs', () {
      expect(quarterPositions([0, 1]), [0, 1]);
      expect(quarterPositions([5]), [0]);
      expect(quarterPositions(const []), isEmpty);
    });
  });
}
