import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/glucose_repository.dart';
import '../data/sources/dexcom_auth.dart';
import '../state/settings_controller.dart';
import '../util/formatting.dart';
import '../util/units.dart';
import 'csv_import_action.dart';
import 'dexcom_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final auth = context.watch<DexcomAuth>();
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
              subtitle: const Text(
                'Reads glucose the Dexcom app has shared to Health Connect. '
                'No Dexcom developer account needed.',
              ),
              enabled: !repo.isLoading,
              onTap: () =>
                  repo.syncFromHealthConnect(
                      window: settings.syncHistoryWindow),
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

          _SectionHeader('Dexcom account'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Advanced. Syncing directly from Dexcom\u2019s API requires your '
              'own developer app registered at developer.dexcom.com — most '
              'people should use Health Connect or a Clarity export instead.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            leading: Icon(
              auth.isConnected
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: auth.isConnected ? Colors.green : theme.colorScheme.outline,
            ),
            title: Text(auth.isConnected ? 'Connected' : 'Not connected'),
            subtitle: Text(
              auth.credentials == null
                  ? 'Add your developer app credentials to sync readings.'
                  : auth.credentials!.environment.label,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DexcomSetupScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Sync now'),
            subtitle: Text(
              repo.lastSync == null
                  ? 'Never synced'
                  : 'Last synced ${formatRelative(repo.lastSync!)}',
            ),
            enabled: auth.isConnected && !repo.isLoading,
            onTap: () =>
                repo.syncFromDexcom(initialWindow: settings.syncHistoryWindow),
          ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded),
            title: const Text('History to sync'),
            // The explanation goes full-width below rather than in the
            // subtitle, which the dropdown squeezes into a narrow column.
            trailing: DropdownButton<int?>(
              value: settings.syncHistoryDays,
              onChanged: (v) => settings.setSyncHistoryDays(v),
              items: [
                for (final days in SettingsController.syncHistoryOptions)
                  DropdownMenuItem(value: days, child: Text(_syncLabel(days))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
            child: Text(
              'Applies to both Health Connect and the Dexcom API. Dexcom caps '
              'each request at 30 days, so a longer window is more requests '
              'and a slower first sync — not a hard limit.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: const Text('Re-download full history'),
            subtitle: Text('Fetches ${_syncLabel(settings.syncHistoryDays)
                .toLowerCase()} again'),
            enabled: auth.isConnected && !repo.isLoading,
            onTap: () => repo.syncFromDexcom(
              fullHistory: true,
              initialWindow: settings.syncHistoryWindow,
            ),
          ),
          const Divider(height: 32),

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
