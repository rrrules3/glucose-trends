/// Rate-of-change classification reported alongside each EGV.
///
/// Names match the strings returned by Dexcom API v3 so parsing is a lookup.
enum GlucoseTrend {
  doubleUp('↑↑', 'Rising fast'),
  singleUp('↑', 'Rising'),
  fortyFiveUp('↗', 'Rising slowly'),
  flat('→', 'Steady'),
  fortyFiveDown('↘', 'Falling slowly'),
  singleDown('↓', 'Falling'),
  doubleDown('↓↓', 'Falling fast'),
  none('', 'No trend'),
  notComputable('?', 'Not computable'),
  rateOutOfRange('⇕', 'Rate out of range');

  const GlucoseTrend(this.arrow, this.label);

  final String arrow;
  final String label;

  static GlucoseTrend parse(String? raw) {
    if (raw == null) return GlucoseTrend.none;
    for (final t in GlucoseTrend.values) {
      if (t.name.toLowerCase() == raw.toLowerCase()) return t;
    }
    return GlucoseTrend.none;
  }
}
