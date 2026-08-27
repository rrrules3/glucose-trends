import 'package:shared_preferences/shared_preferences.dart';

import '../models/glucose_reading.dart';
import '../models/trend.dart';

/// Local cache of every reading the app has seen, so history survives restarts
/// and is available offline.
///
/// Readings are delta-encoded into a single string: a 90-day history is ~26k
/// readings, and storing them as JSON would be several megabytes. Each record
/// becomes `<Δminutes>.<mg/dL>.<trendIndex>` in base-36, which keeps the same
/// history under a few hundred kilobytes.
class ReadingStore {
  ReadingStore(this._prefs);

  final SharedPreferences _prefs;

  static const _readingsKey = 'readings_v1';
  static const _lastSyncKey = 'last_sync';
  static const _sourceKey = 'source_kind';

  static Future<ReadingStore> open() async =>
      ReadingStore(await SharedPreferences.getInstance());

  DateTime? get lastSync {
    final raw = _prefs.getString(_lastSyncKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setLastSync(DateTime time) =>
      _prefs.setString(_lastSyncKey, time.toIso8601String());

  /// Name of the [DataSourceKind] the cached readings came from, so the label
  /// survives a restart instead of being guessed.
  String? get sourceKindName => _prefs.getString(_sourceKey);

  Future<void> setSourceKindName(String name) =>
      _prefs.setString(_sourceKey, name);

  List<GlucoseReading> load() {
    final raw = _prefs.getString(_readingsKey);
    if (raw == null || raw.isEmpty) return [];
    return decode(raw);
  }

  Future<void> save(List<GlucoseReading> readings) async {
    await _prefs.setString(_readingsKey, encode(readings));
  }

  Future<void> clear() async {
    await _prefs.remove(_readingsKey);
    await _prefs.remove(_lastSyncKey);
    await _prefs.remove(_sourceKey);
  }

  static String encode(List<GlucoseReading> readings) {
    if (readings.isEmpty) return '';
    final sorted = [...readings]..sort();
    final buffer = StringBuffer();
    var previousMinute = 0;
    for (var i = 0; i < sorted.length; i++) {
      final r = sorted[i];
      final minute = r.time.millisecondsSinceEpoch ~/ 60000;
      // The first record carries an absolute minute; the rest are deltas.
      final encodedMinute = i == 0 ? minute : minute - previousMinute;
      previousMinute = minute;
      if (i > 0) buffer.write(';');
      buffer
        ..write(encodedMinute.toRadixString(36))
        ..write('.')
        ..write(r.valueMgdl.toRadixString(36))
        ..write('.')
        ..write(r.trend.index.toRadixString(36));
    }
    return buffer.toString();
  }

  static List<GlucoseReading> decode(String raw) {
    final out = <GlucoseReading>[];
    var minute = 0;
    for (final (i, entry) in raw.split(';').indexed) {
      final parts = entry.split('.');
      if (parts.length != 3) continue;
      final delta = int.tryParse(parts[0], radix: 36);
      final value = int.tryParse(parts[1], radix: 36);
      final trendIndex = int.tryParse(parts[2], radix: 36);
      if (delta == null || value == null) continue;
      minute = i == 0 ? delta : minute + delta;
      out.add(GlucoseReading(
        time: DateTime.fromMillisecondsSinceEpoch(minute * 60000),
        valueMgdl: value,
        trend: trendIndex != null && trendIndex < GlucoseTrend.values.length
            ? GlucoseTrend.values[trendIndex]
            : GlucoseTrend.none,
      ));
    }
    return out;
  }
}
