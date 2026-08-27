import 'package:glucose_trends/data/sources/clarity_csv_importer.dart';
import 'package:glucose_trends/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shaped like a real Clarity export: patient-info rows first, then EGV rows
/// interleaved with other event types.
const _mgdlExport = '''
Index,Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Event Subtype,Patient Info,Device Info,Source Device ID,Glucose Value (mg/dL),Insulin Value (u),Carb Value (grams),Duration (hh:mm:ss),Glucose Rate of Change (mg/dL/min),Transmitter Time (Long Integer),Transmitter ID
1,,FirstName,,Alex,,,,,,,,,
2,,LastName,,Rivera,,,,,,,,,
3,,DateOfBirth,,1990-01-01,,,,,,,,,
4,2024-05-01T08:00:00,EGV,,,,G7 Sensor,112,,,,0.4,,ABC123
5,2024-05-01T08:05:00,EGV,,,,G7 Sensor,Low,,,,-1.2,,ABC123
6,2024-05-01T08:10:00,EGV,,,,G7 Sensor,High,,,,2.1,,ABC123
7,2024-05-01T08:15:00,Carbs,,,,,,,45,,,,
8,2024-05-01T08:20:00,Insulin,Fast-Acting,,,,,4.5,,,,,
9,2024-05-01T08:25:00,EGV,,,,G7 Sensor,187,,,,0.1,,ABC123
''';

const _mmolExport = '''
Index,Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Event Subtype,Patient Info,Device Info,Source Device ID,Glucose Value (mmol/L)
1,2024-05-01T08:00:00,EGV,,,,G7 Sensor,6.2
2,2024-05-01T08:05:00,EGV,,,,G7 Sensor,10.0
''';

void main() {
  final importer = ClarityCsvImporter();

  test('parses EGV rows and skips other event types', () {
    final result = importer.parse(_mgdlExport);

    expect(result.readings, hasLength(4));
    expect(result.detectedUnit, GlucoseUnit.mgdl);
    // 3 patient-info rows + carbs + insulin.
    expect(result.skippedRows, 5);
  });

  test('maps Low and High sentinels to the sensor reporting limits', () {
    final readings = importer.parse(_mgdlExport).readings;

    expect(readings[1].valueMgdl, 39);
    expect(readings[1].isBelowRange, isTrue);
    expect(readings[2].valueMgdl, 401);
    expect(readings[2].isAboveRange, isTrue);
  });

  test('returns readings sorted ascending by time', () {
    final readings = importer.parse(_mgdlExport).readings;
    for (var i = 1; i < readings.length; i++) {
      expect(readings[i].time.isAfter(readings[i - 1].time), isTrue);
    }
  });

  test('converts an mmol/L export into canonical mg/dL', () {
    final result = importer.parse(_mmolExport);

    expect(result.detectedUnit, GlucoseUnit.mmoll);
    expect(result.readings.first.valueMgdl, 112); // 6.2 * 18.0182
    expect(result.readings.last.valueMgdl, 180);
  });

  test('handles CRLF line endings', () {
    final result = importer.parse(_mgdlExport.replaceAll('\n', '\r\n'));
    expect(result.readings, hasLength(4));
  });

  test('handles a space-separated timestamp', () {
    final result = importer.parse(
      'Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Glucose Value (mg/dL)\n'
      '2024-05-01 08:00:00,EGV,112\n',
    );
    expect(result.readings.single.time, DateTime(2024, 5, 1, 8));
  });

  test('de-duplicates rows sharing a timestamp', () {
    final result = importer.parse(
      'Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Glucose Value (mg/dL)\n'
      '2024-05-01T08:00:00,EGV,112\n'
      '2024-05-01T08:00:00,EGV,113\n',
    );
    expect(result.readings, hasLength(1));
  });

  test('rejects a file that is not a Clarity export', () {
    expect(
      () => importer.parse('name,email\nAlex,alex@example.com\n'),
      throwsA(isA<CsvImportException>()),
    );
  });

  test('rejects a Clarity-shaped file with no readings in it', () {
    expect(
      () => importer.parse(
        'Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Glucose Value (mg/dL)\n'
        '2024-05-01T08:00:00,Carbs,\n',
      ),
      throwsA(isA<CsvImportException>()),
    );
  });

  test('rejects an empty file', () {
    expect(() => importer.parse(''), throwsA(isA<CsvImportException>()));
  });
}
