import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'loopback_redirect_server.dart';

/// OAuth endpoint paths, versioned independently of the data endpoints.
///
/// These live under `/v3` alongside the v3 data API — the older `/v2` paths are
/// from a previous revision of Dexcom's docs and are not what the current API
/// publishes.
const kOauthLoginPath = '/v3/oauth2/login';
const kOauthTokenPath = '/v3/oauth2/token';

/// Which Dexcom environment to talk to.
///
/// The sandbox serves realistic fake data for six demo users and accepts any
/// password, so the app is fully usable before you have production approval.
enum DexcomEnvironment {
  sandbox('https://sandbox-api.dexcom.com', 'Sandbox (demo data)'),
  production('https://api.dexcom.com', 'Production (your data)');

  const DexcomEnvironment(this.baseUrl, this.label);
  final String baseUrl;
  final String label;
}

class DexcomCredentials {
  const DexcomCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.environment,
  });

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final DexcomEnvironment environment;

  bool get isComplete =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && redirectUri.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'redirectUri': redirectUri,
        'environment': environment.name,
      };

  static DexcomCredentials fromJson(Map<String, dynamic> j) =>
      DexcomCredentials(
        clientId: j['clientId'] as String? ?? '',
        clientSecret: j['clientSecret'] as String? ?? '',
        redirectUri:
            j['redirectUri'] as String? ?? DexcomAuth.defaultRedirectUri,
        environment: DexcomEnvironment.values.firstWhere(
          (e) => e.name == j['environment'],
          orElse: () => DexcomEnvironment.sandbox,
        ),
      );
}

class DexcomTokens {
  DexcomTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Treat tokens as stale a minute early to avoid racing the expiry.
  bool get isExpired =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 1)));

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
      };

  static DexcomTokens fromJson(Map<String, dynamic> j) => DexcomTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}

class DexcomAuthException implements Exception {
  DexcomAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Runs the Dexcom OAuth2 authorization-code flow and keeps tokens fresh.
///
/// Tokens live in the platform keystore (Android Keychain/EncryptedSharedPrefs)
/// via [FlutterSecureStorage] — never in plain shared preferences.
class DexcomAuth extends ChangeNotifier {
  DexcomAuth({FlutterSecureStorage? storage, http.Client? client})
      : _storage = storage ?? const FlutterSecureStorage(),
        _http = client ?? http.Client();

  /// Keychain policy for the stored tokens on iOS.
  ///
  /// `first_unlock_this_device` keeps them readable after a reboot the user has
  /// unlocked once, but marks them non-migratory: restoring an iCloud or
  /// encrypted-device backup onto a different phone will not carry someone's
  /// Dexcom session with it. `synchronizable: false` keeps them out of iCloud
  /// Keychain for the same reason.
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  /// Must match the redirect URI registered on developer.dexcom.com exactly.
  ///
  /// Dexcom's portal rejects custom schemes — it accepts only `http://` or
  /// `https://` — so this uses the loopback redirect that RFC 8252 defines for
  /// native apps. The port is part of the registered URI and therefore fixed;
  /// changing it here means changing it in the portal too.
  static const defaultRedirectUri = 'http://localhost:8423/callback';

  static const _tokenKey = 'dexcom_tokens';
  static const _credsKey = 'dexcom_credentials';

  final FlutterSecureStorage _storage;
  final http.Client _http;

  DexcomTokens? _tokens;
  DexcomCredentials? _credentials;

  /// The listener for a login already in progress, if any.
  ///
  /// Tapping Connect, leaving the browser without finishing, and tapping
  /// Connect again is the obvious thing to do after a failed attempt — but the
  /// first call is still parked on [LoopbackRedirectServer.waitForRedirect]
  /// holding the port, so the second bind fails. Abandoning the earlier attempt
  /// keeps the retry working.
  LoopbackRedirectServer? _pendingLogin;

  DexcomCredentials? get credentials => _credentials;
  bool get isConnected => _tokens != null;

  Future<void> load() async {
    final rawCreds = await _storage.read(key: _credsKey, iOptions: _iosOptions);
    if (rawCreds != null) {
      _credentials = DexcomCredentials.fromJson(
          jsonDecode(rawCreds) as Map<String, dynamic>);
    }
    final rawTokens = await _storage.read(key: _tokenKey, iOptions: _iosOptions);
    if (rawTokens != null) {
      _tokens =
          DexcomTokens.fromJson(jsonDecode(rawTokens) as Map<String, dynamic>);
    }
    notifyListeners();
  }

  Future<void> saveCredentials(DexcomCredentials creds) async {
    _credentials = creds;
    await _storage.write(
      key: _credsKey,
      value: jsonEncode(creds.toJson()),
      iOptions: _iosOptions,
    );
    notifyListeners();
  }

  Future<void> _saveTokens(DexcomTokens? tokens) async {
    _tokens = tokens;
    if (tokens == null) {
      await _storage.delete(key: _tokenKey, iOptions: _iosOptions);
    } else {
      await _storage.write(
        key: _tokenKey,
        value: jsonEncode(tokens.toJson()),
        iOptions: _iosOptions,
      );
    }
    notifyListeners();
  }

  Future<void> disconnect() => _saveTokens(null);

  /// Runs the full authorization-code flow and stores the resulting tokens.
  ///
  /// The app listens on the loopback interface, opens Dexcom's login page in
  /// the system browser, and waits for the browser to be redirected back to
  /// that listener with the authorization code.
  Future<void> connect() async {
    final creds = _credentials;
    if (creds == null || !creds.isComplete) {
      throw DexcomAuthException(
          'Add your Dexcom client ID and secret in Settings first.');
    }

    final redirect = Uri.parse(creds.redirectUri);
    if (!redirect.isScheme('http') && !redirect.isScheme('https')) {
      throw DexcomAuthException(
          'Dexcom only accepts http:// or https:// redirect URIs. '
          'Use ${DexcomAuth.defaultRedirectUri} and register the same value '
          'in the Dexcom portal.');
    }
    if (!redirect.hasPort) {
      throw DexcomAuthException(
          'The redirect URI needs an explicit port, e.g. '
          '${DexcomAuth.defaultRedirectUri}.');
    }

    final state = _randomState();
    final authUrl = Uri.parse('${creds.environment.baseUrl}$kOauthLoginPath')
        .replace(queryParameters: {
      'client_id': creds.clientId,
      'redirect_uri': creds.redirectUri,
      'response_type': 'code',
      'scope': 'offline_access',
      'state': state,
    });

    // Abandon any earlier attempt still holding the port, then bind before
    // launching so the redirect cannot arrive before the listener is ready.
    await _pendingLogin?.close();
    _pendingLogin = null;

    final server = await LoopbackRedirectServer.start(redirect.port);
    _pendingLogin = server;
    try {
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw DexcomAuthException(
            'Could not open a browser for the Dexcom login.');
      }

      final returned = await server.waitForRedirect();

      if (returned.queryParameters['state'] != state) {
        throw DexcomAuthException(
            'OAuth state mismatch — login was not trusted.');
      }
      final error = returned.queryParameters['error'];
      if (error != null) {
        throw DexcomAuthException('Dexcom returned an error: $error');
      }
      final code = returned.queryParameters['code'];
      if (code == null) {
        throw DexcomAuthException(
            'Dexcom did not return an authorization code.');
      }

      // The redirect arrives while the browser is still on top, so the app is
      // backgrounded. Several OEMs — Samsung among them — cut network access
      // for background apps, and netd blocks the DNS lookup outright
      // (`isBlocked=true`), which surfaces as a misleading "Failed host
      // lookup". The loopback redirect itself is local and unaffected; only
      // this call goes out to Dexcom, so it waits for the app to come forward.
      await _waitUntilForeground();

      await _exchange({
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': creds.redirectUri,
      });
    } finally {
      await server.close();
      if (identical(_pendingLogin, server)) _pendingLogin = null;
    }
  }

  /// Returns a valid access token, refreshing it first if needed.
  Future<String> accessToken() async {
    final tokens = _tokens;
    if (tokens == null) {
      throw DexcomAuthException('Not connected to Dexcom.');
    }
    if (!tokens.isExpired) return tokens.accessToken;

    await _exchange({
      'grant_type': 'refresh_token',
      'refresh_token': tokens.refreshToken,
    });
    return _tokens!.accessToken;
  }

  /// Completes once the app is in the foreground, or after [timeout].
  static Future<void> _waitUntilForeground({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final binding = WidgetsBinding.instance;
    if (binding.lifecycleState == AppLifecycleState.resumed) return;

    final resumed = Completer<void>();
    final listener = AppLifecycleListener(
      onResume: () {
        if (!resumed.isCompleted) resumed.complete();
      },
    );
    try {
      // Falling through on timeout is deliberate: attempting and reporting a
      // real network error beats hanging silently.
      await resumed.future.timeout(timeout, onTimeout: () {});
    } finally {
      listener.dispose();
    }
  }

  Future<void> _exchange(Map<String, String> extraFields) async {
    final creds = _credentials!;
    final response = await _postWithRetry(
      Uri.parse('${creds.environment.baseUrl}$kOauthTokenPath'),
      {
        'client_id': creds.clientId,
        'client_secret': creds.clientSecret,
        ...extraFields,
      },
    );

    if (response.statusCode != 200) {
      // A rejected refresh token is unrecoverable — force a fresh login.
      if (extraFields['grant_type'] == 'refresh_token') {
        await _saveTokens(null);
      }
      throw DexcomAuthException(
          'Token request failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _saveTokens(DexcomTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresAt: DateTime.now()
          .add(Duration(seconds: (json['expires_in'] as num).toInt())),
    ));
  }

  /// POST with a couple of quick retries on transport failures.
  ///
  /// Network access is restored a moment after an app returns to the
  /// foreground, not instantly, so the first attempt can still lose its DNS
  /// lookup. Only transport errors are retried — an HTTP error response is
  /// returned as-is for the caller to interpret.
  Future<http.Response> _postWithRetry(
    Uri uri,
    Map<String, String> body, {
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
      try {
        return await _http.post(
          uri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        );
      } on SocketException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      }
    }
    throw DexcomAuthException(
        'Could not reach Dexcom ($lastError). Check your connection and try '
        'again.');
  }

  static String _randomState() {
    final rng = Random.secure();
    return base64Url
        .encode(List<int>.generate(16, (_) => rng.nextInt(256)))
        .replaceAll('=', '');
  }
}
