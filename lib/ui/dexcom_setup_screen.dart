import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/glucose_repository.dart';
import '../data/sources/dexcom_auth.dart';
import '../data/sources/loopback_redirect_server.dart';

/// Collects the developer-app credentials Dexcom's OAuth flow requires and
/// runs the login.
///
/// Dexcom issues client IDs per application, not per user, so there is no way
/// to ship one — each person registers their own app at developer.dexcom.com.
class DexcomSetupScreen extends StatefulWidget {
  const DexcomSetupScreen({super.key});

  @override
  State<DexcomSetupScreen> createState() => _DexcomSetupScreenState();
}

class _DexcomSetupScreenState extends State<DexcomSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _clientId;
  late final TextEditingController _clientSecret;
  late final TextEditingController _redirectUri;
  late DexcomEnvironment _environment;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final existing = context.read<DexcomAuth>().credentials;
    _clientId = TextEditingController(text: existing?.clientId ?? '');
    _clientSecret = TextEditingController(text: existing?.clientSecret ?? '');
    _redirectUri = TextEditingController(
        text: existing?.redirectUri ?? DexcomAuth.defaultRedirectUri);
    _environment = existing?.environment ?? DexcomEnvironment.sandbox;
  }

  @override
  void dispose() {
    _clientId.dispose();
    _clientSecret.dispose();
    _redirectUri.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<DexcomAuth>();
    final repo = context.read<GlucoseRepository>();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await auth.saveCredentials(DexcomCredentials(
        clientId: _clientId.text.trim(),
        clientSecret: _clientSecret.text.trim(),
        redirectUri: _redirectUri.text.trim(),
        environment: _environment,
      ));
      await auth.connect();
      await repo.syncFromDexcom(fullHistory: true);
      if (mounted) Navigator.of(context).pop();
    } on LoginAbandonedException {
      // Superseded by a newer attempt, or cancelled — say nothing.
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DexcomAuth>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect Dexcom')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Register a free app at developer.dexcom.com, set its '
                  'redirect URI to the value below, then paste the client ID '
                  'and secret here.\n\n'
                  'The redirect URI below must match the portal exactly — '
                  'Dexcom accepts only http:// or https://, so the app listens '
                  'on that local port during login.\n\n'
                  'Sandbox needs no password — the login page shows a '
                  'drop-down of simulated accounts, including a G7 one. '
                  'Production returns your own readings, delayed about three '
                  'hours on a standard developer account.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<DexcomEnvironment>(
              segments: [
                for (final e in DexcomEnvironment.values)
                  ButtonSegment(
                    value: e,
                    label: Text(e == DexcomEnvironment.sandbox
                        ? 'Sandbox'
                        : 'Production'),
                  ),
              ],
              selected: {_environment},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _environment = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _clientId,
              decoration: const InputDecoration(
                labelText: 'Client ID',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _clientSecret,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Client secret',
                border: OutlineInputBorder(),
                helperText: 'Stored in the Android keystore, never in plain text',
              ),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _redirectUri,
              decoration: const InputDecoration(
                labelText: 'Redirect URI',
                border: OutlineInputBorder(),
                helperText: 'Must match the Dexcom portal exactly',
              ),
              validator: (v) {
                final uri = Uri.tryParse(v?.trim() ?? '');
                if (uri == null ||
                    !(uri.isScheme('http') || uri.isScheme('https'))) {
                  // Dexcom's portal rejects custom schemes outright.
                  return 'Must start with http:// or https://';
                }
                if (!uri.hasPort) {
                  return 'Include the port, e.g. ${DexcomAuth.defaultRedirectUri}';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(auth.isConnected ? 'Reconnect' : 'Connect'),
              onPressed: _busy ? null : _connect,
            ),
            if (auth.isConnected) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Disconnect'),
                onPressed: _busy ? null : () => auth.disconnect(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
