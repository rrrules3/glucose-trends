import 'package:glucose_trends/models/time_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 24, 15, 0);

  test('anchors to the newest reading, not the wall clock', () {
    // A Clarity export that ended eight days ago.
    final latest = DateTime(2026, 8, 16, 9, 30);
    final w = resolveWindow(
      duration: const Duration(hours: 24),
      latestReading: latest,
      now: now,
    );

    expect(w.end, latest);
    expect(w.start, latest.subtract(const Duration(hours: 24)));
    // The whole point: the imported data falls inside the default window.
    expect(w.contains(latest), isTrue);
    expect(w.contains(latest.subtract(const Duration(hours: 3))), isTrue);
  });

  test('uses the clock when there are no readings', () {
    final w = resolveWindow(duration: const Duration(hours: 24), now: now);
    expect(w.end, now);
  });

  test('never anchors into the future on a skewed timestamp', () {
    final w = resolveWindow(
      duration: const Duration(hours: 6),
      latestReading: now.add(const Duration(days: 2)),
      now: now,
    );
    expect(w.end, now);
  });

  test('a live reading behaves the same as anchoring to now', () {
    final latest = now.subtract(const Duration(minutes: 4));
    final w = resolveWindow(
      duration: const Duration(hours: 24),
      latestReading: latest,
      now: now,
    );
    expect(now.difference(w.end).inMinutes, lessThan(5));
  });

  test('span matches the requested duration for every preset', () {
    for (final preset in TimeframeOption.presets) {
      final d = preset.duration;
      if (d == null) continue; // "Custom" carries no duration.
      final w = resolveWindow(duration: d, latestReading: now, now: now);
      expect(w.span, d, reason: 'preset ${preset.label}');
    }
  });
}
