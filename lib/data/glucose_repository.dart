import 'package:flutter/foundation.dart';

import '../models/glucose_reading.dart';
import 'reading_store.dart';
import 'sources/clarity_csv_importer.dart';
import 'sources/demo_data.dart';
import 'sources/health_connect_source.dart';

/// Where the currently-loaded readings came from.
enum DataSourceKind {
  none('No data'),
  demo('Demo data'),
  healthConnect('Health Connect'),
  csv('Clarity CSV');

  const DataSourceKind(this.label);
  final String label;
}

/// Owns the reading history and the ways of filling it.
///
/// Readings from the API and from a CSV import are merged into one timeline
/// keyed by timestamp, so importing an old export alongside a live sync widens
/// the history instead of replacing it.
class GlucoseRepository extends ChangeNotifier {
  GlucoseRepository({
    required ReadingStore store,
    HealthConnectSource? healthConnect,
  })  : _store = store,
        _healthConnect = healthConnect ?? HealthConnectSource() {
    _readings = _store.load();
    if (_readings.isNotEmpty) {
      _sourceKind = DataSourceKind.values.firstWhere(
        (k) => k.name == _store.sourceKindName,
        orElse: () => DataSourceKind.none,
      );
    }
  }

  final ReadingStore _store;
  final HealthConnectSource _healthConnect;

  HealthConnectSource get healthConnect => _healthConnect;

  List<GlucoseReading> _readings = [];
  DataSourceKind _sourceKind = DataSourceKind.none;
  bool _isLoading = false;
  String? _error;
  double _progress = 0;

  /// Full history, ascending by time.
  List<GlucoseReading> get readings => List.unmodifiable(_readings);
  DataSourceKind get sourceKind => _sourceKind;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get progress => _progress;
  DateTime? get lastSync => _store.lastSync;
  bool get hasData => _readings.isNotEmpty;

  GlucoseReading? get latest => _readings.isEmpty ? null : _readings.last;

  /// Readings falling inside [start, end], inclusive.
  ///
  /// The history is kept sorted, so this binary-searches both ends rather than
  /// scanning — the 90-day view holds ~26k readings and this runs on every
  /// timeframe change.
  List<GlucoseReading> inWindow(DateTime start, DateTime end) {
    if (_readings.isEmpty) return const [];
    final from = _lowerBound(start);
    final to = _lowerBound(end.add(const Duration(milliseconds: 1)));
    if (from >= to) return const [];
    return _readings.sublist(from, to);
  }

  int _lowerBound(DateTime t) {
    var lo = 0, hi = _readings.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_readings[mid].time.isBefore(t)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Pull glucose the Dexcom app has written to Health Connect.
  ///
  /// Needs nothing from Dexcom — no developer account, no approval — only the
  /// user's permission on the device. Their readings arrive with the same ~3
  /// hour delay Dexcom applies to that feed.
  Future<void> syncFromHealthConnect({
    Duration? window = const Duration(days: 90),
    bool fullHistory = false,
  }) async {
    if (!_healthConnect.isSupportedPlatform) {
      _fail('Health Connect is only available on Android.');
      return;
    }

    _begin();
    try {
      if (!await _healthConnect.hasPermission()) {
        if (!await _healthConnect.requestPermission()) {
          _fail('Permission to read glucose from Health Connect was declined.');
          return;
        }
      }

      final now = DateTime.now();
      // A null window means "everything readable"; the source clamps to what
      // Health Connect will actually serve, so the bound here is only there to
      // keep the query finite.
      final fullSpan = window ?? const Duration(days: 365 * 5);
      // Same overlap as the API sync, so a partially-written tail is corrected
      // rather than left with a gap.
      final start = (fullHistory || _readings.isEmpty)
          ? now.subtract(fullSpan)
          : _readings.last.time.subtract(const Duration(hours: 1));

      final fetched = await _healthConnect.fetch(start: start, end: now);
      if (fetched.isEmpty && _readings.isEmpty) {
        // Turning sharing on does not backfill: Samsung Health, at least,
        // only forwards readings recorded after the connection exists. Someone
        // who enables sharing and immediately syncs sees nothing and concludes
        // the app is broken, so the message has to name that case.
        _fail('No glucose found in Health Connect.\n\n'
            'Turn on sharing in the Dexcom app, then check back — apps '
            'usually only share readings recorded after sharing is switched '
            'on, so it can take a few hours to appear.');
        return;
      }

      _merge(fetched);
      await _store.save(_readings);
      await _store.setLastSync(now);
      _finish(DataSourceKind.healthConnect);
    } catch (e) {
      _fail('Could not read from Health Connect: $e');
    }
  }

  /// Merge a Clarity CSV export into the history.
  Future<CsvImportResult> importCsv(String contents) async {
    _begin();
    try {
      final result = ClarityCsvImporter().parse(contents);
      _merge(result.readings);
      await _store.save(_readings);
      _finish(DataSourceKind.csv);
      return result;
    } on CsvImportException catch (e) {
      _fail(e.message);
      rethrow;
    } catch (e) {
      _fail('Could not read the CSV: $e');
      rethrow;
    }
  }

  /// Replace the history with synthetic data for exploring the app.
  Future<void> loadDemoData() async {
    _begin();
    _readings = generateDemoReadings();
    await _store.save(_readings);
    _finish(DataSourceKind.demo);
  }

  Future<void> clearAll() async {
    _readings = [];
    _sourceKind = DataSourceKind.none;
    _error = null;
    await _store.clear();
    notifyListeners();
  }

  /// Union of existing and incoming readings, newest write winning on ties.
  void _merge(List<GlucoseReading> incoming) {
    if (incoming.isEmpty) return;
    final byTime = <DateTime, GlucoseReading>{
      for (final r in _readings) r.time: r,
    };
    for (final r in incoming) {
      byTime[r.time] = r;
    }
    _readings = byTime.values.toList()..sort();
  }

  void _begin() {
    _isLoading = true;
    _error = null;
    _progress = 0;
    notifyListeners();
  }

  void _finish(DataSourceKind kind) {
    _isLoading = false;
    _progress = 1;
    _sourceKind = kind;
    _store.setSourceKindName(kind.name);
    notifyListeners();
  }

  void _fail(String message) {
    _isLoading = false;
    _error = message;
    notifyListeners();
  }
}
