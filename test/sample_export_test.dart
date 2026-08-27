import 'dart:io';

import 'package:glucose_trends/data/sources/clarity_csv_importer.dart';
import 'package:glucose_trends/models/glucose_stats.dart';
import 'package:glucose_trends/util/units.dart';
import 'package:flutter_test/flutter_test.dart';

/// End-to-end check against the full-size sample export in `sample_data/`,
/// which is shaped like a real Clarity file (metadata rows, carb and insulin
/// events, Low/High sentinels) rather than a hand-written fixture.
void main() {
  test('imports the bundled sample export and summarises it', () {
    final file = File('sample_data/clarity_export_sample.csv');
    expect(file.existsSync(), isTrue,
        reason: 'sample_data/clarity_export_sample.csv should be checked in');

    final result = ClarityCsvImporter().parse(file.readAsStringSync());

    // 7 days at 5-minute cadence.
    expect(result.readings, hasLength(2016));
    expect(result.detectedUnit, GlucoseUnit.mgdl);
    // 3 metadata rows + a carb and an insulin row on each of 7 days.
    expect(result.skippedRows, 17);

    final stats = GlucoseStats.from(
      result.readings,
      range: const TargetRange(),
      windowSpan: const Duration(days: 7),
    );

    expect(stats.count, 2016);
    expect(stats.minReading!.valueMgdl, lessThan(stats.maxReading!.valueMgdl));
    expect(stats.meanMgdl, greaterThan(80));
    expect(stats.meanMgdl, lessThan(200));
    expect(stats.sensorCoverage, closeTo(1.0, 0.01));
  });
}
