import 'package:flutter/material.dart';

import 'units.dart';

/// Colour language used everywhere glucose is shown, so a value has the same
/// meaning on the chart, the stat cards and the range bar.
class GlucoseColors {
  static const veryLow = Color(0xFFE0484B);
  static const low = Color(0xFFE86E3A);
  static const inRange = Color(0xFF3FB86F);
  static const high = Color(0xFFE8B23A);
  static const veryHigh = Color(0xFFD97A2B);

  /// Below 54 mg/dL is "clinically significant hypoglycaemia"; above 250 is the
  /// matching level-2 hyperglycaemia threshold.
  static const veryLowThresholdMgdl = 54;
  static const veryHighThresholdMgdl = 250;

  static Color forValue(int mgdl, TargetRange range) {
    if (mgdl < veryLowThresholdMgdl) return veryLow;
    if (mgdl < range.lowMgdl) return low;
    if (mgdl > veryHighThresholdMgdl) return veryHigh;
    if (mgdl > range.highMgdl) return high;
    return inRange;
  }

  static String describe(int mgdl, TargetRange range) {
    if (mgdl < veryLowThresholdMgdl) return 'Very low';
    if (mgdl < range.lowMgdl) return 'Low';
    if (mgdl > veryHighThresholdMgdl) return 'Very high';
    if (mgdl > range.highMgdl) return 'High';
    return 'In range';
  }
}
