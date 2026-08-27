import 'package:glucose_trends/data/reading_store.dart';
import 'package:glucose_trends/models/glucose_reading.dart';
import 'package:glucose_trends/models/trend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('encoding round-trips values, timestamps and trends', () {
    final readings = [
      GlucoseReading(
          time: DateTime(2024, 5, 1, 8),
          valueMgdl: 112,
          trend: GlucoseTrend.fortyFiveUp),
      GlucoseReading(
          time: DateTime(2024, 5, 1, 8, 5),
          valueMgdl: 39,
          trend: GlucoseTrend.doubleDown),
      GlucoseReading(
          time: DateTime(2024, 5, 1, 8, 10),
          valueMgdl: 401,
          trend: GlucoseTrend.flat),
    ];

    final decoded = ReadingStore.decode(ReadingStore.encode(readings));
    expect(decoded, equals(readings));
  });

  test('sorts on encode so decode always yields ordered readings', () {
    final readings = [
      GlucoseReading(time: DateTime(2024, 5, 1, 9), valueMgdl: 150),
      GlucoseReading(time: DateTime(2024, 5, 1, 8), valueMgdl: 100),
    ];

    final decoded = ReadingStore.decode(ReadingStore.encode(readings));
    expect(decoded.first.valueMgdl, 100);
    expect(decoded.last.valueMgdl, 150);
  });

  test('delta encoding keeps 90 days of history compact', () {
    final readings = [
      for (var i = 0; i < 25920; i++)
        GlucoseReading(
          time: DateTime(2024, 1, 1).add(Duration(minutes: i * 5)),
          valueMgdl: 100 + (i % 90),
        ),
    ];

    final encoded = ReadingStore.encode(readings);
    // Under 300 KB; the equivalent JSON would be several megabytes.
    expect(encoded.length, lessThan(300 * 1024));
    expect(ReadingStore.decode(encoded), hasLength(25920));
  });

  test('empty input round-trips to an empty list', () {
    expect(ReadingStore.encode(const []), '');
    expect(ReadingStore.decode(''), isEmpty);
  });

  test('persists readings across store instances', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ReadingStore.open();

    final readings = [
      GlucoseReading(time: DateTime(2024, 5, 1, 8), valueMgdl: 120),
    ];
    await store.save(readings);

    final reopened = await ReadingStore.open();
    expect(reopened.load(), equals(readings));

    await reopened.clear();
    expect((await ReadingStore.open()).load(), isEmpty);
  });
}
