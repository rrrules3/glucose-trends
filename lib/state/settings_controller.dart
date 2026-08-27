import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../util/units.dart';

/// User preferences that shape presentation only — never the stored data.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static const _unitKey = 'glucose_unit';
  static const _lowKey = 'target_low_mgdl';
  static const _highKey = 'target_high_mgdl';
  static const _timeframeKey = 'timeframe_label';
  static const _syncDaysKey = 'sync_history_days';

  static Future<SettingsController> open() async =>
      SettingsController(await SharedPreferences.getInstance());

  GlucoseUnit get unit {
    final name = _prefs.getString(_unitKey);
    return GlucoseUnit.values.firstWhere(
      (u) => u.name == name,
      orElse: () => GlucoseUnit.mmoll,
    );
  }

  Future<void> setUnit(GlucoseUnit unit) async {
    await _prefs.setString(_unitKey, unit.name);
    notifyListeners();
  }

  TargetRange get targetRange => TargetRange(
        lowMgdl: _prefs.getInt(_lowKey) ?? 70,
        highMgdl: _prefs.getInt(_highKey) ?? 180,
      );

  Future<void> setTargetRange(TargetRange range) async {
    await _prefs.setInt(_lowKey, range.lowMgdl);
    await _prefs.setInt(_highKey, range.highMgdl);
    notifyListeners();
  }

  String get timeframeLabel => _prefs.getString(_timeframeKey) ?? '24h';

  Future<void> setTimeframeLabel(String label) async {
    await _prefs.setString(_timeframeKey, label);
    notifyListeners();
  }

  /// Options for how far back a full sync reaches. `null` means everything
  /// Dexcom still holds.
  static const syncHistoryOptions = <int?>[30, 90, 180, 365, null];

  /// How far back to pull on a full sync; `null` for everything available.
  ///
  /// Stored as days, with 0 standing in for "all" since preferences hold no
  /// nullable int. Dexcom's 30-day cap is per request, not on total history,
  /// so a longer window just means more requests.
  Duration? get syncHistoryWindow {
    final days = _prefs.getInt(_syncDaysKey) ?? 90;
    return days <= 0 ? null : Duration(days: days);
  }

  int? get syncHistoryDays {
    final days = _prefs.getInt(_syncDaysKey) ?? 90;
    return days <= 0 ? null : days;
  }

  Future<void> setSyncHistoryDays(int? days) async {
    await _prefs.setInt(_syncDaysKey, days ?? 0);
    notifyListeners();
  }
}
