import 'package:glucose_trends/data/sources/health_connect_source.dart';
import 'package:health/health.dart';
import 'package:flutter_test/flutter_test.dart';

HealthDataPoint point(
  DateTime at,
  num value, {
  HealthDataUnit unit = HealthDataUnit.MILLIGRAM_PER_DECILITER,
}) =>
    HealthDataPoint(
      uuid: '${at.microsecondsSinceEpoch}',
      value: NumericHealthValue(numericValue: value),
      type: HealthDataType.BLOOD_GLUCOSE,
      unit: unit,
      dateFrom: at,
      dateTo: at,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'device',
      sourceId: 'com.dexcom.g7',
      sourceName: 'Dexcom G7',
    );

void main() {
  group('parseHealthPoints', () {
    test('reads mg/dL records straight through', () {
      final readings = parseHealthPoints([
        point(DateTime(2026, 8, 20, 8), 112),
        point(DateTime(2026, 8, 20, 8, 5), 118),
      ]);

      expect(readings, hasLength(2));
      expect(readings.first.valueMgdl, 112);
      expect(readings.last.valueMgdl, 118);
    });

    test('converts mmol/L records to the canonical mg/dL', () {
      final readings = parseHealthPoints([
        point(DateTime(2026, 8, 20, 8), 6.2,
            unit: HealthDataUnit.MILLIMOLES_PER_LITER),
      ]);
      expect(readings.single.valueMgdl, 112);
    });

    test('infers the unit from magnitude when none is given', () {
      // 6.2 can only be mmol/L; 112 can only be mg/dL. The plausible ranges
      // do not overlap, so this is safe.
      final asMmol = parseHealthPoints(
          [point(DateTime(2026, 8, 20, 8), 6.2, unit: HealthDataUnit.NO_UNIT)]);
      final asMgdl = parseHealthPoints(
          [point(DateTime(2026, 8, 20, 9), 112, unit: HealthDataUnit.NO_UNIT)]);

      expect(asMmol.single.valueMgdl, 112);
      expect(asMgdl.single.valueMgdl, 112);
    });

    test('drops values no CGM could produce', () {
      final readings = parseHealthPoints([
        point(DateTime(2026, 8, 20, 8), 0),
        point(DateTime(2026, 8, 20, 9), 5000),
        point(DateTime(2026, 8, 20, 10), 120),
      ]);
      expect(readings.single.valueMgdl, 120);
    });

    test('ignores records carrying a non-numeric value', () {
      final odd = HealthDataPoint(
        uuid: 'x',
        value: WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.RUNNING,
        ),
        type: HealthDataType.BLOOD_GLUCOSE,
        unit: HealthDataUnit.MILLIGRAM_PER_DECILITER,
        dateFrom: DateTime(2026, 8, 20, 8),
        dateTo: DateTime(2026, 8, 20, 8),
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'd',
        sourceId: 's',
        sourceName: 'n',
      );
      expect(parseHealthPoints([odd]), isEmpty);
    });

    test('de-duplicates records sharing a timestamp', () {
      final at = DateTime(2026, 8, 20, 8);
      expect(parseHealthPoints([point(at, 112), point(at, 113)]), hasLength(1));
    });

    test('returns readings ascending regardless of input order', () {
      final readings = parseHealthPoints([
        point(DateTime(2026, 8, 20, 10), 130),
        point(DateTime(2026, 8, 20, 8), 110),
        point(DateTime(2026, 8, 20, 9), 120),
      ]);
      expect(readings.map((r) => r.valueMgdl), [110, 120, 130]);
    });

    test('is empty-safe', () {
      expect(parseHealthPoints(const []), isEmpty);
    });
  });

  group('HealthConnectAvailability', () {
    test('only "ready" counts as usable', () {
      expect(HealthConnectAvailability.ready.isReady, isTrue);
      for (final other in HealthConnectAvailability.values
          .where((v) => v != HealthConnectAvailability.ready)) {
        expect(other.isReady, isFalse, reason: other.name);
        expect(other.label, isNotEmpty);
      }
    });
  });
}
