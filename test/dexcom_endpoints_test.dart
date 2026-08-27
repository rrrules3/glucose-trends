import 'package:glucose_trends/data/sources/dexcom_auth.dart';
import 'package:flutter_test/flutter_test.dart';

/// These paths are the one part of the integration that cannot be caught by
/// analysis or by any test that stubs the network: get them wrong and the app
/// compiles, runs, and fails only when a real user tries to log in. Pinning
/// them here makes a drift from Dexcom's published API a test failure.
void main() {
  group('OAuth endpoints', () {
    test('use the v3 paths the Dexcom API publishes', () {
      expect(kOauthLoginPath, '/v3/oauth2/login');
      expect(kOauthTokenPath, '/v3/oauth2/token');
    });

    test('are not the superseded v2 paths', () {
      expect(kOauthLoginPath, isNot(contains('/v2/')));
      expect(kOauthTokenPath, isNot(contains('/v2/')));
    });
  });

  group('Environments', () {
    test('point at the documented hosts', () {
      expect(DexcomEnvironment.production.baseUrl, 'https://api.dexcom.com');
      expect(DexcomEnvironment.sandbox.baseUrl,
          'https://sandbox-api.dexcom.com');
    });

    test('are https, since tokens travel over them', () {
      for (final e in DexcomEnvironment.values) {
        expect(Uri.parse(e.baseUrl).scheme, 'https');
      }
    });

    test('carry no trailing slash, so path concatenation stays correct', () {
      for (final e in DexcomEnvironment.values) {
        expect(e.baseUrl, isNot(endsWith('/')));
        expect(
          '${e.baseUrl}$kOauthTokenPath',
          matches(RegExp(r'^https://[a-z\-.]+/v3/oauth2/token$')),
        );
      }
    });

    test('sandbox is the default for new credentials', () {
      final creds = DexcomCredentials.fromJson(const {});
      expect(creds.environment, DexcomEnvironment.sandbox);
      expect(creds.redirectUri, DexcomAuth.defaultRedirectUri);
      expect(creds.isComplete, isFalse);
    });
  });
}
