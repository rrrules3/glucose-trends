import 'package:fl_chart/fl_chart.dart';
import 'package:glucose_trends/util/chart_axis.dart';
import 'package:flutter_test/flutter_test.dart';

TitleMeta meta({
  required double min,
  required double max,
  required double interval,
  double axisSize = 900,
}) =>
    TitleMeta(
      min: min,
      max: max,
      parentAxisSize: axisSize,
      axisPosition: 0,
      appliedInterval: interval,
      sideTitles: const SideTitles(),
      formattedValue: '',
      axisSide: AxisSide.bottom,
      rotationQuarterTurns: 0,
    );

void main() {
  group('quarterIndices', () {
    test('always includes the first and last day', () {
      for (final count in [5, 8, 15, 31, 91]) {
        final picks = quarterIndices(count);
        expect(picks.first, 0, reason: 'count $count');
        expect(picks.last, count - 1, reason: 'count $count');
      }
    });

    test('gives exactly four labels once there are enough days', () {
      expect(quarterIndices(8), hasLength(4));
      expect(quarterIndices(15), hasLength(4));
      expect(quarterIndices(31), hasLength(4));
      expect(quarterIndices(91), hasLength(4));
    });

    test('picks whole days, never a fraction between them', () {
      // The bug this replaces: a literal quarter of a 7-day span fell at 08:00
      // on the third day, so the label sat beside its own data point.
      final picks = quarterIndices(8); // Aug 17..24
      expect(picks, [0, 2, 5, 7]);
      for (final i in picks) {
        expect(i, equals(i.toInt()));
      }
    });

    test('divides a 30-day and 90-day window evenly', () {
      expect(quarterIndices(31), [0, 10, 20, 30]);
      expect(quarterIndices(91), [0, 30, 60, 90]);
    });

    test('degrades gracefully with very few days', () {
      expect(quarterIndices(0), isEmpty);
      expect(quarterIndices(1), [0]);
      expect(quarterIndices(3), [0, 1, 2]);
    });
  });

  group('monthAwareDateLabels', () {
    test('names the month once within a single month', () {
      final labels = monthAwareDateLabels([
        DateTime(2026, 8, 17),
        DateTime(2026, 8, 19),
        DateTime(2026, 8, 21),
        DateTime(2026, 8, 24),
      ]);
      expect(labels, ['Aug 17', '19', '21', '24']);
    });

    test('names the month again where it changes', () {
      final labels = monthAwareDateLabels([
        DateTime(2026, 7, 25),
        DateTime(2026, 8, 4),
        DateTime(2026, 8, 14),
        DateTime(2026, 8, 24),
      ]);
      expect(labels, ['Jul 25', 'Aug 4', '14', '24']);
    });

    test('names every month when each label crosses one', () {
      final labels = monthAwareDateLabels([
        DateTime(2026, 5, 26),
        DateTime(2026, 6, 25),
        DateTime(2026, 7, 25),
        DateTime(2026, 8, 24),
      ]);
      expect(labels, ['May 26', 'Jun 25', 'Jul 25', 'Aug 24']);
    });

    test('treats a year boundary as a month change', () {
      final labels = monthAwareDateLabels([
        DateTime(2026, 12, 20),
        DateTime(2026, 12, 27),
        DateTime(2027, 1, 3),
      ]);
      expect(labels, ['Dec 20', '27', 'Jan 3']);
    });

    test('is empty-safe', () {
      expect(monthAwareDateLabels(const []), isEmpty);
    });
  });

  group('collidesWithAxisEnd', () {
    final m = meta(min: 0, max: 1000, interval: 100, axisSize: 1000);

    test('never suppresses the axis end labels themselves', () {
      expect(collidesWithAxisEnd(0, m), isFalse);
      expect(collidesWithAxisEnd(1000, m), isFalse);
    });

    test('suppresses a tick crowding either end', () {
      expect(collidesWithAxisEnd(30, m), isTrue);
      expect(collidesWithAxisEnd(970, m), isTrue);
    });

    test('leaves ticks with room alone', () {
      expect(collidesWithAxisEnd(500, m), isFalse);
      expect(collidesWithAxisEnd(100, m), isFalse);
    });

    test('is inert on a degenerate axis', () {
      expect(collidesWithAxisEnd(5, meta(min: 5, max: 5, interval: 1)), isFalse);
    });
  });
}
