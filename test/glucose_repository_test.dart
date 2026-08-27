import 'package:glucose_trends/data/glucose_repository.dart';
import 'package:glucose_trends/data/reading_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GlucoseRepository> makeRepo() async {
  SharedPreferences.setMockInitialValues({});
  return GlucoseRepository(store: await ReadingStore.open());
}

const _csvHeader =
    'Timestamp (YYYY-MM-DDThh:mm:ss),Event Type,Glucose Value (mg/dL)\n';

void main() {
  test('starts with no data', () async {
    final repo = await makeRepo();
    expect(repo.hasData, isFalse);
    expect(repo.latest, isNull);
    expect(repo.sourceKind, DataSourceKind.none);
  });

  test('demo data spans 90 days at a 5-minute cadence', () async {
    final repo = await makeRepo();
    await repo.loadDemoData();

    expect(repo.sourceKind, DataSourceKind.demo);
    // 90 days / 5 min.
    expect(repo.readings.length, 25920);
    expect(repo.latest, isNotNull);
  });

  test('inWindow returns only readings inside the range, inclusive', () async {
    final repo = await makeRepo();
    await repo.importCsv(
      '$_csvHeader'
      '2024-05-01T08:00:00,EGV,100\n'
      '2024-05-01T09:00:00,EGV,110\n'
      '2024-05-01T10:00:00,EGV,120\n'
      '2024-05-01T11:00:00,EGV,130\n',
    );

    final window = repo.inWindow(
      DateTime(2024, 5, 1, 9),
      DateTime(2024, 5, 1, 10),
    );
    expect(window.map((r) => r.valueMgdl), [110, 120]);
  });

  test('inWindow is empty when the range misses the data', () async {
    final repo = await makeRepo();
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,100\n');

    expect(
      repo.inWindow(DateTime(2024, 6, 1), DateTime(2024, 6, 2)),
      isEmpty,
    );
  });

  test('binary search over a large history agrees with a linear scan',
      () async {
    final repo = await makeRepo();
    await repo.loadDemoData();

    final all = repo.readings;
    final start = all[5000].time;
    final end = all[5500].time;

    final expected =
        all.where((r) => !r.time.isBefore(start) && !r.time.isAfter(end));
    expect(repo.inWindow(start, end).length, expected.length);
  });

  test('a second import merges instead of replacing', () async {
    final repo = await makeRepo();
    await repo.importCsv('${_csvHeader}2024-05-02T08:00:00,EGV,100\n');
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,90\n');

    expect(repo.readings, hasLength(2));
    // Merged history stays sorted, so the older import lands first.
    expect(repo.readings.first.valueMgdl, 90);
    expect(repo.latest!.valueMgdl, 100);
  });

  test('overlapping imports overwrite by timestamp rather than duplicate',
      () async {
    final repo = await makeRepo();
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,100\n');
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,105\n');

    expect(repo.readings, hasLength(1));
    expect(repo.readings.single.valueMgdl, 105);
  });

  test('imported history survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await ReadingStore.open();
    final repo = GlucoseRepository(store: store);
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,100\n');

    final reopened = GlucoseRepository(store: await ReadingStore.open());
    expect(reopened.readings, hasLength(1));
  });

  test('remembers which source the cached readings came from', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = GlucoseRepository(store: await ReadingStore.open());
    await repo.loadDemoData();

    final reopened = GlucoseRepository(store: await ReadingStore.open());
    expect(reopened.sourceKind, DataSourceKind.demo);
  });

  test('clearAll empties both memory and storage', () async {
    final repo = await makeRepo();
    await repo.loadDemoData();
    await repo.clearAll();

    expect(repo.hasData, isFalse);
    expect((await ReadingStore.open()).load(), isEmpty);
  });

  test('a failed import surfaces an error and leaves history intact', () async {
    final repo = await makeRepo();
    await repo.importCsv('${_csvHeader}2024-05-01T08:00:00,EGV,100\n');

    await expectLater(
      repo.importCsv('name,email\nAlex,a@example.com\n'),
      throwsA(anything),
    );
    expect(repo.error, isNotNull);
    expect(repo.readings, hasLength(1));
  });
}
