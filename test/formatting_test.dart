import 'package:glucose_trends/util/formatting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPercent', () {
    test('reserves 0% and 100% for genuinely empty or full buckets', () {
      expect(formatPercent(0), '0%');
      expect(formatPercent(1), '100%');
    });

    test('never rounds a real excursion away to 0%', () {
      // One reading above range in a fortnight of 5-minute readings.
      expect(formatPercent(1 / 4033), '<1%');
      expect(formatPercent(0.004), '<1%');
    });

    test('never rounds an imperfect stretch up to 100%', () {
      expect(formatPercent(4032 / 4033), '>99%');
      expect(formatPercent(0.996), '>99%');
    });

    test('rounds normally in between', () {
      expect(formatPercent(0.5), '50%');
      expect(formatPercent(0.734), '73%');
      expect(formatPercent(0.015), '2%');
    });

    test('clamps nonsensical input rather than emitting it', () {
      expect(formatPercent(-0.2), '0%');
      expect(formatPercent(1.5), '100%');
    });
  });
}
