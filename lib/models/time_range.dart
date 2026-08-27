/// A user-selectable window over the reading history.
class TimeframeOption {
  const TimeframeOption(this.label, this.duration);

  final String label;

  /// `null` means "custom" — the range comes from an explicit start/end.
  final Duration? duration;

  static const presets = <TimeframeOption>[
    TimeframeOption('3h', Duration(hours: 3)),
    TimeframeOption('6h', Duration(hours: 6)),
    TimeframeOption('12h', Duration(hours: 12)),
    TimeframeOption('24h', Duration(hours: 24)),
    TimeframeOption('7d', Duration(days: 7)),
    TimeframeOption('14d', Duration(days: 14)),
    TimeframeOption('30d', Duration(days: 30)),
    TimeframeOption('90d', Duration(days: 90)),
    TimeframeOption('Custom', null),
  ];
}

/// A concrete, resolved [start, end) window.
class DateWindow {
  const DateWindow(this.start, this.end);

  factory DateWindow.lastly(Duration d, {DateTime? now}) {
    final e = now ?? DateTime.now();
    return DateWindow(e.subtract(d), e);
  }

  final DateTime start;
  final DateTime end;

  Duration get span => end.difference(start);

  bool contains(DateTime t) => !t.isBefore(start) && !t.isAfter(end);

  @override
  String toString() => 'DateWindow($start → $end)';
}

/// Resolve a preset duration into a concrete window.
///
/// The window ends at the newest reading rather than at the wall clock. A
/// Clarity export is often days or weeks old, and anchoring to "now" would show
/// an empty chart immediately after a successful import — the user cannot tell
/// that apart from the import having failed. With live syncing the newest
/// reading is only minutes old, so this is indistinguishable from anchoring to
/// now, minus the dead space at the right edge.
DateWindow resolveWindow({
  required Duration duration,
  DateTime? latestReading,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  // Never anchor into the future, in case a reading carries a skewed timestamp.
  final end = latestReading == null || latestReading.isAfter(clock)
      ? clock
      : latestReading;
  return DateWindow(end.subtract(duration), end);
}
