import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/glucose_repository.dart';
import '../state/settings_controller.dart';
import '../util/formatting.dart';
import '../util/units.dart';
import 'csv_import_action.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final repo = context.watch<GlucoseRepository>();
    final theme = Theme.of(context);
    final unit = settings.unit;
    final range = settings.targetRange;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _SectionHeader('Display'),
          ListTile(
            title: const Text('Glucose units'),
            subtitle: Text(unit.label),
            trailing: SegmentedButton<GlucoseUnit>(
              segments: [
                for (final u in GlucoseUnit.values)
                  ButtonSegment(value: u, label: Text(u.label)),
              ],
              selected: {unit},
              showSelectedIcon: false,
              onSelectionChanged: (s) => settings.setUnit(s.first),
            ),
          ),
          ListTile(
            title: const Text('Target range'),
            subtitle: Text(
              '${unit.format(range.lowMgdl)} – '
              '${unit.format(range.highMgdl, withUnit: true)}  ·  '
              'used for time-in-range and colour coding',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: RangeSlider(
              values: RangeValues(
                range.lowMgdl.toDouble(),
                range.highMgdl.toDouble(),
              ),
              min: 50,
              max: 300,
              divisions: 50,
              labels: RangeLabels(
                unit.format(range.lowMgdl),
                unit.format(range.highMgdl),
              ),
              onChanged: (values) => settings.setTargetRange(
                TargetRange(
                  lowMgdl: values.start.round(),
                  highMgdl: values.end.round(),
                ),
              ),
            ),
          ),
          const Divider(height: 32),

          if (repo.healthConnect.isSupportedPlatform) ...[
            _SectionHeader('Health Connect'),
            ListTile(
              leading: const Icon(Icons.favorite_rounded),
              title: const Text('Sync from Health Connect'),
              subtitle: Text(
                repo.lastSync == null
                    ? 'Reads glucose the Dexcom app has shared to Health '
                        'Connect.'
                    : 'Last synced ${formatRelative(repo.lastSync!)}',
              ),
              enabled: !repo.isLoading,
              onTap: () =>
                  repo.syncFromHealthConnect(
                      window: settings.syncHistoryWindow),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_rounded),
              title: const Text('History to sync'),
              trailing: DropdownButton<int?>(
                value: settings.syncHistoryDays,
                onChanged: (v) => settings.setSyncHistoryDays(v),
                items: [
                  for (final days in SettingsController.syncHistoryOptions)
                    DropdownMenuItem(
                        value: days, child: Text(_syncLabel(days))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Text(
                'How far back a full sync reaches. Health Connect serves only '
                'the last 30 days unless you granted history access.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
              child: Text(
                'Turn sharing on in the Dexcom app first (Connections → '
                'Health Connect). Readings arrive about three hours after the '
                'sensor takes them, and sharing usually only covers readings '
                'recorded after you switch it on — so nothing appears '
                'immediately.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const Divider(height: 32),
          ],

          _SectionHeader('Import & data'),
          ListTile(
            leading: const Icon(Icons.upload_file_rounded),
            title: const Text('Import Clarity CSV'),
            subtitle: const Text(
                'clarity.dexcom.com → Export data. Merges into your history.'),
            onTap: () => importClarityCsv(context, repo),
          ),
          ListTile(
            leading: const Icon(Icons.science_rounded),
            title: const Text('Load demo data'),
            subtitle: const Text('90 days of synthetic readings'),
            onTap: () => repo.loadDemoData(),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded,
                color: theme.colorScheme.error),
            title: Text('Clear stored readings',
                style: TextStyle(color: theme.colorScheme.error)),
            subtitle: Text('${repo.readings.length} readings on this device'),
            onTap: () => _confirmClear(context, repo),
          ),
          const Divider(height: 32),

          _SectionHeader('About'),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom,
            ),
            child: const Text(
              'This app reads Dexcom G7 data through the official Dexcom API '
              'or a Clarity CSV export. It does not connect to the sensor over '
              'Bluetooth, and it is not a medical device — do not use it to '
              'make treatment decisions. Always confirm with the Dexcom app '
              'or a fingerstick.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, GlucoseRepository repo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear stored readings?'),
        content: const Text(
            'This removes the local copy of your glucose history. Data still '
            'in your Dexcom account can be synced again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await repo.clearAll();
  }
}

String _syncLabel(int? days) => switch (days) {
      null => 'Everything available',
      365 => 'Last year',
      final d when d % 30 == 0 => 'Last ${d ~/ 30} months',
      final d => 'Last $d days',
    };

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
