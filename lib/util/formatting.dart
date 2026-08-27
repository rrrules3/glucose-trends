import 'package:intl/intl.dart';

import '../models/time_range.dart';

/// Timestamp format that suits the width of the window being shown — a
/// clock time inside a day, a weekday over a week, a date beyond that.
String formatReadingTime(DateTime t, Duration span) {
  if (span <= const Duration(hours: 36)) return DateFormat.jm().format(t);
  if (span <= const Duration(days: 8)) return DateFormat('EEE h:mm a').format(t);
  return DateFormat('MMM d, h:mm a').format(t);
}

String formatAxisLabel(DateTime t, Duration span) {
  if (span <= const Duration(hours: 36)) return DateFormat.j().format(t);
  if (span <= const Duration(days: 14)) return DateFormat('E').format(t);
  return DateFormat('MMM d').format(t);
}

String formatWindow(DateWindow window) {
  final fmt = window.span <= const Duration(hours: 36)
      ? DateFormat('MMM d, h:mm a')
      : DateFormat('MMM d, y');
  return '${fmt.format(window.start)} — ${fmt.format(window.end)}';
}

String formatRelative(DateTime t) {
  final delta = DateTime.now().difference(t);
  if (delta.isNegative) return 'just now';
  if (delta.inMinutes < 1) return 'just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) return '${delta.inHours} hr ago';
  if (delta.inDays < 7) return '${delta.inDays} d ago';
  return DateFormat('MMM d').format(t);
}

String formatHour(int hour) => DateFormat.j().format(DateTime(2024, 1, 1, hour));

/// Format a 0–1 fraction as a percentage without ever rounding a non-zero
/// share to "0%" or a partial share up to "100%".
///
/// A single high reading in a fortnight is a real excursion, and reporting it
/// as "Above 0%" next to a "High" maximum reads as a contradiction. Only an
/// exactly-empty or exactly-full bucket gets the round number.
String formatPercent(double fraction) {
  if (fraction <= 0) return '0%';
  if (fraction >= 1) return '100%';
  final percent = fraction * 100;
  if (percent < 1) return '<1%';
  if (percent > 99) return '>99%';
  return '${percent.round()}%';
}
