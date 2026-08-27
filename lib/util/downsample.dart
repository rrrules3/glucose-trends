import '../models/glucose_reading.dart';

/// Reduce a long series to something a chart can draw without stalling, while
/// keeping every visible extreme.
///
/// A 90-day window holds ~26,000 readings. Naively taking every Nth point would
/// drop the spikes and lows that are the whole reason to look at the chart, so
/// each bucket contributes its minimum and its maximum, emitted in the order
/// they occurred. The resulting envelope matches what the full series looks
/// like at screen resolution.
List<GlucoseReading> downsampleForChart(
  List<GlucoseReading> readings, {
  int targetBuckets = 400,
}) {
  if (readings.length <= targetBuckets * 2) return readings;

  final bucketSize = readings.length / targetBuckets;
  final out = <GlucoseReading>[];

  for (var b = 0; b < targetBuckets; b++) {
    final start = (b * bucketSize).floor();
    final end = ((b + 1) * bucketSize).floor().clamp(start + 1, readings.length);
    if (start >= readings.length) break;

    var minIndex = start;
    var maxIndex = start;
    for (var i = start; i < end; i++) {
      if (readings[i].valueMgdl < readings[minIndex].valueMgdl) minIndex = i;
      if (readings[i].valueMgdl > readings[maxIndex].valueMgdl) maxIndex = i;
    }

    if (minIndex == maxIndex) {
      out.add(readings[minIndex]);
    } else if (minIndex < maxIndex) {
      out..add(readings[minIndex])..add(readings[maxIndex]);
    } else {
      out..add(readings[maxIndex])..add(readings[minIndex]);
    }
  }

  return out;
}
