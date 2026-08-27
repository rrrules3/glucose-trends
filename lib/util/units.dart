import 'package:flutter/foundation.dart';

/// Factor relating the two glucose units. 1 mmol/L == 18.0182 mg/dL.
const double kMgdlPerMmol = 18.0182;

enum GlucoseUnit {
  mgdl('mg/dL'),
  mmoll('mmol/L');

  const GlucoseUnit(this.label);
  final String label;

  /// Convert a canonical mg/dL value into this unit.
  double fromMgdl(num mgdl) =>
      this == GlucoseUnit.mgdl ? mgdl.toDouble() : mgdl / kMgdlPerMmol;

  double toMgdl(num value) =>
      this == GlucoseUnit.mgdl ? value.toDouble() : value * kMgdlPerMmol;

  /// mg/dL is conventionally shown as a whole number, mmol/L to one decimal.
  String format(num mgdl, {bool withUnit = false}) {
    final v = fromMgdl(mgdl);
    final text =
        this == GlucoseUnit.mgdl ? v.round().toString() : v.toStringAsFixed(1);
    return withUnit ? '$text $label' : text;
  }

  /// Step size for range sliders and axis ticks, in mg/dL.
  double get niceStepMgdl => this == GlucoseUnit.mgdl ? 1 : kMgdlPerMmol / 10;
}

@immutable
class TargetRange {
  const TargetRange({this.lowMgdl = 70, this.highMgdl = 180});

  /// Below this is "low"; the standard consensus threshold is 70 mg/dL.
  final int lowMgdl;

  /// Above this is "high"; the standard consensus threshold is 180 mg/dL.
  final int highMgdl;

  bool contains(int mgdl) => mgdl >= lowMgdl && mgdl <= highMgdl;

  TargetRange copyWith({int? lowMgdl, int? highMgdl}) => TargetRange(
        lowMgdl: lowMgdl ?? this.lowMgdl,
        highMgdl: highMgdl ?? this.highMgdl,
      );

  @override
  bool operator ==(Object other) =>
      other is TargetRange &&
      other.lowMgdl == lowMgdl &&
      other.highMgdl == highMgdl;

  @override
  int get hashCode => Object.hash(lowMgdl, highMgdl);
}
