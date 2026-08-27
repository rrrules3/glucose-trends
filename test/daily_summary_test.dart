import 'package:glucose_trends/models/glucose_reading.dart';
import 'package:glucose_trends/models/glucose_stats.dart';
import 'package:flutter_test/flutter_test.dart';

GlucoseReading at(DateTime t, int mgdl) =>
    GlucoseReading(time: t, valueMgdl: mgdl);

void main() {
  group('dailySummaries', () {
    test('groups by calendar day and averages within each', () {
      final summaries = dailySummaries([
        at(DateTime(2026, 8, 10, 8), 100),
        at(DateTime(2026, 8, 10, 20), 200),
        at(DateTime(2026, 8, 11, 9), 120),
      ]);

      expect(summaries, hasLength(2));
      expect(summaries[0].day, DateTime(2026, 8, 10));
      expect(summaries[0].meanMgdl, 150);
      expect(summaries[1].meanMgdl, 120);
    });

    test('reports each day\'s own high and low, with their times', () {
      final summaries = dailySummaries([
        at(DateTime(2026, 8, 10, 3), 62),
        at(DateTime(2026, 8, 10, 8), 140),
        at(DateTime(2026, 8, 10, 13, 30), 265),
      ]);

      final day = summaries.single;
      expect(day.min.valueMgdl, 62);
      expect(day.min.time.hour, 3);
      expect(day.max.valueMgdl, 265);
      expect(day.max.time.hour, 13);
      expect(day.max.time.minute, 30);
    });

    test('a day\'s extremes are its own, not the whole window\'s', () {
      final summaries = dailySummaries([
        at(DateTime(2026, 8, 10, 8), 90),
        at(DateTime(2026, 8, 10, 9), 110),
        // The window's true maximum falls on the second day.
        at(DateTime(2026, 8, 11, 8), 300),
        at(DateTime(2026, 8, 11, 9), 280),
      ]);

      expect(summaries[0].max.valueMgdl, 110);
      expect(summaries[1].max.valueMgdl, 300);
      expect(summaries[1].min.valueMgdl, 280);
    });

    test('returns days in ascending order regardless of input order', () {
      final summaries = dailySummaries([
        at(DateTime(2026, 8, 12, 8), 100),
        at(DateTime(2026, 8, 10, 8), 100),
        at(DateTime(2026, 8, 11, 8), 100),
      ]);

      expect(
        summaries.map((s) => s.day.day),
        [10, 11, 12],
      );
    });

    test('coverage reflects how much of the day was sampled', () {
      final full = dailySummaries([
        for (var i = 0; i < 288; i++)
          at(DateTime(2026, 8, 10).add(Duration(minutes: i * 5)), 110),
      ]).single;
      expect(full.coverage, closeTo(1.0, 0.001));

      final sparse = dailySummaries([at(DateTime(2026, 8, 10, 8), 110)]).single;
      expect(sparse.coverage, lessThan(0.01));
    });

    test('does not merge the same clock time on different days', () {
      final summaries = dailySummaries([
        at(DateTime(2026, 8, 10, 8), 100),
        at(DateTime(2026, 9, 10, 8), 200),
      ]);
      expect(summaries, hasLength(2));
    });

    test('is empty-safe', () {
      expect(dailySummaries(const []), isEmpty);
    });
  });
}
