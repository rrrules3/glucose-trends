import 'trend.dart';

/// A single estimated glucose value (EGV).
///
/// [valueMgdl] is always stored in mg/dL — the canonical unit used by both the
/// Dexcom API and the transmitter itself. Conversion to mmol/L happens only at
/// the presentation layer so that stored data never depends on a user setting.
class GlucoseReading implements Comparable<GlucoseReading> {
  const GlucoseReading({
    required this.time,
    required this.valueMgdl,
    this.trend = GlucoseTrend.none,
  });

  /// Local display time of the reading.
  final DateTime time;

  final int valueMgdl;

  final GlucoseTrend trend;

  /// The G7 reports "Low"/"High" outside 40–400 mg/dL rather than a number.
  bool get isBelowRange => valueMgdl <= 39;
  bool get isAboveRange => valueMgdl >= 401;

  @override
  int compareTo(GlucoseReading other) => time.compareTo(other.time);

  @override
  String toString() => 'GlucoseReading($time, $valueMgdl mg/dL, ${trend.name})';

  @override
  bool operator ==(Object other) =>
      other is GlucoseReading &&
      other.time == time &&
      other.valueMgdl == valueMgdl &&
      other.trend == trend;

  @override
  int get hashCode => Object.hash(time, valueMgdl, trend);
}
