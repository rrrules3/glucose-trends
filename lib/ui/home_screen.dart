import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/glucose_repository.dart';
import '../models/glucose_stats.dart';
import '../models/time_range.dart';
import '../state/settings_controller.dart';
import '../util/formatting.dart';
import 'csv_import_action.dart';
import 'settings_screen.dart';
import 'widgets/daily_summary_chart.dart';
import 'widgets/current_reading_card.dart';
import 'widgets/pattern_chart.dart';
import 'widgets/stats_panel.dart';
import 'widgets/time_in_range_bar.dart';
import 'widgets/timeframe_selector.dart';
import 'widgets/trends_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Set when the user picks an explicit range; presets clear it.
  DateWindow? _customWindow;

  @override
  void initState() {
    super.initState();
    // A custom range is not persisted, so a stored "Custom" label would leave
    // the chip selected with no window behind it. Fall back to the default.
    final settings = context.read<SettingsController>();
    if (settings.timeframeLabel == 'Custom') {
      settings.setTimeframeLabel('24h');
    }
  }

  DateWindow _resolveWindow(String label, DateTime? latestReading) {
    if (_customWindow != null) return _customWindow!;
    final preset = TimeframeOption.presets.firstWhere(
      (p) => p.label == label,
      orElse: () => TimeframeOption.presets[3],
    );
    return resolveWindow(
      duration: preset.duration ?? const Duration(hours: 24),
      latestReading: latestReading,
    );
  }

  Future<void> _pickCustomRange(SettingsController settings) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 400)),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      ),
      helpText: 'Select timeframe',
    );
    if (picked == null || !mounted) return;

    setState(() {
      // The picker returns dates; widen to cover the whole end day.
      _customWindow = DateWindow(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
      );
    });
    await settings.setTimeframeLabel('Custom');
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final repo = context.watch<GlucoseRepository>();
    final theme = Theme.of(context);

    final window = _resolveWindow(settings.timeframeLabel, repo.latest?.time);
    final readings = repo.inWindow(window.start, window.end);
    final stats = GlucoseStats.from(
      readings,
      range: settings.targetRange,
      windowSpan: window.span,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Glucose Chart'),
        actions: [
          if (repo.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Sync from Dexcom',
              onPressed: () =>
                  repo.syncFromHealthConnect(window: settings.syncHistoryWindow),
            ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            repo.syncFromHealthConnect(window: settings.syncHistoryWindow),
        child: ListView(
          // Flutter draws edge-to-edge on modern Android, so the list runs
          // under the gesture/navigation bar. Without the system inset the
          // last card can never be scrolled clear of it.
          padding: EdgeInsets.only(
            bottom: 32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            if (repo.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _ErrorBanner(message: repo.error!),
              ),

            // With no history at all, the chart, stat cards and range bar are
            // just empty furniture that pushes the one useful action off
            // screen. Show the empty state on its own instead.
            if (!repo.hasData)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
                child: _EmptyStateActions(repo: repo),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: CurrentReadingCard(
                  reading: repo.latest,
                  unit: settings.unit,
                  range: settings.targetRange,
                  sourceLabel: repo.sourceKind.label,
                ),
              ),
              const SizedBox(height: 12),
              TimeframeSelector(
                selectedLabel: settings.timeframeLabel,
                onSelected: (option) {
                  setState(() => _customWindow = null);
                  settings.setTimeframeLabel(option.label);
                },
                onCustomRequested: () => _pickCustomRange(settings),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  formatWindow(window),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(height: 8),
              // Past a week the raw trace is tens of thousands of points in a
              // few hundred pixels; a point per day stays legible and still
              // carries each day's extremes.
              if (window.span >= DailySummaryChart.threshold) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Row(
                    children: [
                      Text('Daily average',
                          style: theme.textTheme.labelMedium),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Band spans each day\u2019s low to its high. '
                            'Tap a day for its numbers.',
                        child: Icon(Icons.info_outline_rounded,
                            size: 14, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: SizedBox(
                    height: 240,
                    child: DailySummaryChart(
                      summaries: dailySummaries(readings),
                      unit: settings.unit,
                      range: settings.targetRange,
                    ),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: SizedBox(
                    height: 240,
                    child: TrendsChart(
                      readings: readings,
                      window: window,
                      unit: settings.unit,
                      range: settings.targetRange,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: StatsPanel(
                  stats: stats,
                  unit: settings.unit,
                  range: settings.targetRange,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TimeInRangeBar(
                  stats: stats,
                  unit: settings.unit,
                  range: settings.targetRange,
                ),
              ),
              // A one-day window has no repeating pattern to average over.
              if (window.span >= const Duration(days: 2)) ...[
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('Daily pattern', style: theme.textTheme.titleSmall),
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Median with 10th\u201390th percentile band, '
                            'across every day in the timeframe',
                        child: Icon(Icons.info_outline_rounded,
                            size: 15, color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                  child: SizedBox(
                    height: 200,
                    child: PatternChart(
                      buckets: hourlyPattern(readings),
                      unit: settings.unit,
                      range: settings.targetRange,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when there is nothing to chart yet.
///
/// Getting data in is the whole job at this point, so both routes are offered
/// directly rather than buried in Settings.
class _EmptyStateActions extends StatelessWidget {
  const _EmptyStateActions({required this.repo});

  final GlucoseRepository repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final healthConnectAvailable = repo.healthConnect.isSupportedPlatform;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Get your readings in',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              healthConnectAvailable
                  ? 'Connect to Health Connect to pull readings the Dexcom app '
                      'has already shared, or import a Clarity export.'
                  : 'Import an export from Dexcom Clarity to see your history.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Health Connect needs nothing from Dexcom, so it leads where the
            // platform supports it.
            if (healthConnectAvailable) ...[
              FilledButton.icon(
                icon: const Icon(Icons.favorite_rounded),
                label: const Text('Connect Health Connect'),
                onPressed: () => repo.syncFromHealthConnect(
                    window: settings.syncHistoryWindow),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Import Clarity CSV'),
                onPressed: () => importClarityCsv(context, repo),
              ),
            ] else
              FilledButton.icon(
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Import Clarity CSV'),
                onPressed: () => importClarityCsv(context, repo),
              ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.science_rounded, size: 18),
              label: const Text('Try it with demo data'),
              onPressed: () => repo.loadDemoData(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
