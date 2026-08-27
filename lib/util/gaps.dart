import 'package:fl_chart/fl_chart.dart';

import '../models/glucose_reading.dart';

/// A G7 reports every 5 minutes. A break longer than this is missing data —
/// a removed sensor, a dead phone, a partial export — not sampling jitter.
const kSensorGapThreshold = Duration(minutes: 30);

/// Build chart spots that break wherever readings are missing.
///
/// fl_chart joins consecutive spots unconditionally, so without this a
/// three-day hole is drawn as a straight line between the readings either side
/// of it — a confident, smooth trace across data that does not exist. Inserting
/// [FlSpot.nullSpot] splits the line instead, leaving the gap visibly empty.
List<FlSpot> spotsWithGapBreaks(
  List<GlucoseReading> readings,
  FlSpot Function(GlucoseReading) toSpot, {
  Duration threshold = kSensorGapThreshold,
}) {
  final spots = <FlSpot>[];
  for (var i = 0; i < readings.length; i++) {
    if (i > 0 &&
        readings[i].time.difference(readings[i - 1].time) > threshold) {
      spots.add(FlSpot.nullSpot);
    }
    spots.add(toSpot(readings[i]));
  }
  return spots;
}

/// Total time inside [start]–[end] not covered by readings.
///
/// Counts only breaks beyond [threshold], plus any missing stretch at either
/// end of the window, so a normal 5-minute cadence reports as no gap at all.
Duration missingSpan(
  List<GlucoseReading> readings,
  DateTime start,
  DateTime end, {
  Duration threshold = kSensorGapThreshold,
}) {
  if (!start.isBefore(end)) return Duration.zero;
  if (readings.isEmpty) return end.difference(start);

  var missing = Duration.zero;
  final leading = readings.first.time.difference(start);
  if (leading > threshold) missing += leading;
  final trailing = end.difference(readings.last.time);
  if (trailing > threshold) missing += trailing;

  for (var i = 1; i < readings.length; i++) {
    final delta = readings[i].time.difference(readings[i - 1].time);
    if (delta > threshold) missing += delta;
  }
  return missing;
}

/// Day number for a date, computed in UTC so a daylight-saving change cannot
/// shift it by an hour and round to the wrong day.
int dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
