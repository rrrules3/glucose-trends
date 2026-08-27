import 'dart:io';

import 'package:health/health.dart';

import '../../models/glucose_reading.dart';
import '../../util/units.dart';

/// Reads glucose the Dexcom app has written into Android's Health Connect.
///
/// This is the only route that needs nothing from Dexcom: no developer
/// account, no client secret, no partnership approval. The user enables
/// sharing once in the Dexcom app, grants this app read access, and their
/// readings arrive — subject to the same ~3 hour delay Dexcom applies to its
/// Health Connect feed.
///
/// Read-only by design. The app never writes to someone's health record.
class HealthConnectSource {
  HealthConnectSource({Health? health}) : _health = health ?? Health();

  final Health _health;

  static const _types = [HealthDataType.BLOOD_GLUCOSE];
  static const _access = [HealthDataAccess.READ];

  /// Health Connect is Android-only; it is part of the OS from Android 14.
  bool get isSupportedPlatform => Platform.isAndroid;

  /// Whether Health Connect is present and usable on this device.
  Future<HealthConnectAvailability> availability() async {
    if (!isSupportedPlatform) return HealthConnectAvailability.unsupported;
    try {
      final status = _health.getHealthConnectSdkStatus();
      return switch (await status) {
        HealthConnectSdkStatus.sdkAvailable => HealthConnectAvailability.ready,
        HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired =>
          HealthConnectAvailability.needsUpdate,
        _ => HealthConnectAvailability.unavailable,
      };
    } catch (_) {
      return HealthConnectAvailability.unavailable;
    }
  }

  Future<bool> hasPermission() async {
    if (!isSupportedPlatform) return false;
    return await _health.hasPermissions(_types, permissions: _access) ?? false;
  }

  /// Prompts for read access. Returns whether it was granted.
  ///
  /// Health Connect only shows its sheet a limited number of times before
  /// requiring the user to go to system settings, so callers should treat a
  /// refusal as final rather than asking again.
  Future<bool> requestPermission() async {
    if (!isSupportedPlatform) return false;
    await _health.configure();

    final granted = await _health.requestAuthorization(_types,
        permissions: _access);
    if (!granted) return false;

    // Separate, optional grant. Without it Health Connect serves only the last
    // 30 days; with it the longer timeframes work. Failing to get it is not
    // fatal — the reader clamps its window instead.
    if (await _health.isHealthDataHistoryAvailable() &&
        !await _health.isHealthDataHistoryAuthorized()) {
      await _health.requestHealthDataHistoryAuthorization();
    }

    return true;
  }

  /// How far back Health Connect will actually serve.
  ///
  /// 30 days unless the history permission was granted, regardless of what is
  /// asked for — so the caller can say so rather than silently returning a
  /// truncated history.
  Future<Duration?> readableHistory() async {
    if (!isSupportedPlatform) return const Duration(days: 30);
    try {
      if (!await _health.isHealthDataHistoryAvailable()) {
        return const Duration(days: 30);
      }
      return await _health.isHealthDataHistoryAuthorized()
          ? null // unlimited
          : const Duration(days: 30);
    } catch (_) {
      return const Duration(days: 30);
    }
  }

  /// Glucose records between [start] and [end], ascending and de-duplicated.
  Future<List<GlucoseReading>> fetch({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!isSupportedPlatform || !start.isBefore(end)) return const [];
    await _health.configure();

    // Asking beyond the readable window returns nothing useful and can error,
    // so clamp rather than hope.
    final limit = await readableHistory();
    final earliest = limit == null ? start : end.subtract(limit);
    final from = start.isBefore(earliest) ? earliest : start;
    if (!from.isBefore(end)) return const [];

    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: from,
      endTime: end,
    );
    return parseHealthPoints(points);
  }
}

/// Convert Health Connect records into readings.
///
/// Split out from the plugin call so it can be tested without a device.
List<GlucoseReading> parseHealthPoints(List<HealthDataPoint> points) {
  final byTime = <DateTime, GlucoseReading>{};

  for (final point in points) {
    final value = point.value;
    if (value is! NumericHealthValue) continue;

    final mgdl = _toMgdl(value.numericValue.toDouble(), point.unit);
    // Outside what a CGM can report, so more likely a unit mix-up than a real
    // reading; dropping it beats charting a spike that never happened.
    if (mgdl == null || mgdl < 10 || mgdl > 1000) continue;

    // Health Connect timestamps are instants; the rest of the app works in
    // local wall-clock time.
    final time = point.dateFrom.toLocal();
    byTime[time] = GlucoseReading(time: time, valueMgdl: mgdl.round());
  }

  final out = byTime.values.toList()..sort();
  return out;
}

/// Health Connect reports glucose in mmol/L, but the unit an app records
/// against varies, so it is honoured rather than assumed.
double? _toMgdl(double value, HealthDataUnit unit) => switch (unit) {
      HealthDataUnit.MILLIGRAM_PER_DECILITER => value,
      HealthDataUnit.MILLIMOLES_PER_LITER => value * kMgdlPerMmol,
      // No unit given: infer from magnitude. A plausible mg/dL reading is far
      // outside the plausible mmol/L range, so the two never overlap.
      HealthDataUnit.NO_UNIT => value > 35 ? value : value * kMgdlPerMmol,
      _ => null,
    };

enum HealthConnectAvailability {
  ready('Ready'),
  needsUpdate('Health Connect needs updating'),
  unavailable('Health Connect is not available on this device'),
  unsupported('Health Connect is Android-only');

  const HealthConnectAvailability(this.label);
  final String label;

  bool get isReady => this == HealthConnectAvailability.ready;
}
