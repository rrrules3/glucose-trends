import 'dart:math' as math;

import '../../models/glucose_reading.dart';
import '../../models/trend.dart';

/// Generates plausible CGM history so the app is explorable before any account
/// is connected. Purely synthetic — never presented as real data.
List<GlucoseReading> generateDemoReadings({
  Duration span = const Duration(days: 90),
  DateTime? endingAt,
  int seed = 7,
}) {
  final rng = math.Random(seed);
  final end = endingAt ?? DateTime.now();
  final start = end.subtract(span);
  final totalSteps = span.inMinutes ~/ 5;

  final readings = <GlucoseReading>[];
  var value = 120.0;
  // Slow-moving offset so different days don't look identical.
  var dayOffset = 0.0;
  var lastDay = -1;

  for (var i = 0; i < totalSteps; i++) {
    final t = start.add(Duration(minutes: i * 5));
    if (t.day != lastDay) {
      lastDay = t.day;
      dayOffset = (rng.nextDouble() - 0.5) * 30;
    }

    final hour = t.hour + t.minute / 60.0;

    // Dawn phenomenon: a gentle rise between 03:00 and 08:00.
    final dawn = 18 * math.exp(-math.pow(hour - 6, 2) / 4);

    // Meal excursions around 08:00, 12:30 and 19:00.
    var meals = 0.0;
    for (final (mealHour, size) in [(8.0, 65.0), (12.5, 80.0), (19.0, 70.0)]) {
      final dt = hour - mealHour;
      if (dt > 0 && dt < 4) {
        // Fast rise, slower decay.
        meals += size * math.exp(-math.pow(dt - 0.8, 2) / 0.55);
      }
    }

    final target = 105 + dawn + meals + dayOffset;
    // First-order lag toward the target plus sensor noise.
    value += (target - value) * 0.18 + (rng.nextDouble() - 0.5) * 7;
    value = value.clamp(45.0, 320.0);

    final previous = readings.isEmpty ? value : readings.last.valueMgdl;
    readings.add(GlucoseReading(
      time: t,
      valueMgdl: value.round(),
      trend: _trendFromDelta(value - previous),
    ));
  }

  return readings;
}

/// Map a 5-minute change into the trend buckets Dexcom uses (mg/dL/min).
GlucoseTrend _trendFromDelta(double deltaOver5Min) {
  final perMinute = deltaOver5Min / 5;
  if (perMinute >= 3) return GlucoseTrend.doubleUp;
  if (perMinute >= 2) return GlucoseTrend.singleUp;
  if (perMinute >= 1) return GlucoseTrend.fortyFiveUp;
  if (perMinute <= -3) return GlucoseTrend.doubleDown;
  if (perMinute <= -2) return GlucoseTrend.singleDown;
  if (perMinute <= -1) return GlucoseTrend.fortyFiveDown;
  return GlucoseTrend.flat;
}
