import 'package:glucose_trends/models/glucose_reading.dart';
import 'package:glucose_trends/util/downsample.dart';
import 'package:flutter_test/flutter_test.dart';

List<GlucoseReading> series(List<int> values) => [
      for (final (i, v) in values.indexed)
        GlucoseReading(
          time: DateTime(2024, 5, 1).add(Duration(minutes: i * 5)),
          valueMgdl: v,
        ),
    ];

void main() {
  test('leaves short series untouched', () {
    final input = series(List.filled(50, 110));
    expect(downsampleForChart(input, targetBuckets: 100), same(input));
  });

  test('reduces a 90-day series to a chart-sized envelope', () {
    // 90 days at one reading per 5 minutes.
    final input = series(List.generate(25920, (i) => 100 + (i % 80)));
    final out = downsampleForChart(input, targetBuckets: 400);

    expect(out.length, lessThanOrEqualTo(800));
    expect(out.length, greaterThan(400));
  });

  test('preserves the global minimum and maximum', () {
    final values = List.generate(5000, (i) => 100 + (i % 20));
    values[1234] = 41; // a hypo buried mid-series
    values[4321] = 380; // and a spike
    final out = downsampleForChart(series(values), targetBuckets: 50);

    expect(out.map((r) => r.valueMgdl), contains(41));
    expect(out.map((r) => r.valueMgdl), contains(380));
  });

  test('keeps output in chronological order', () {
    final values = List.generate(3000, (i) => 100 + ((i * 37) % 150));
    final out = downsampleForChart(series(values), targetBuckets: 60);

    for (var i = 1; i < out.length; i++) {
      expect(out[i].time.isBefore(out[i - 1].time), isFalse);
    }
  });

  test('handles an empty series', () {
    expect(downsampleForChart(const [], targetBuckets: 10), isEmpty);
  });
}
