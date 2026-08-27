import 'dart:io';

import 'package:glucose_trends/data/sources/dexcom_auth.dart';
import 'package:glucose_trends/data/sources/loopback_redirect_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Exercises the real socket, since the whole point of this class is that a
/// browser on the device can actually reach it.
void main() {
  const port = 8477; // not the production port, to avoid clashing with a run

  test('captures the authorization code from the redirect', () async {
    final server = await LoopbackRedirectServer.start(port);
    addTearDown(server.close);

    final pending = server.waitForRedirect();
    final response = await http.get(
      Uri.parse('http://localhost:$port/callback?code=abc123&state=xyz'),
    );

    expect(response.statusCode, 200);
    // The browser lands on a human-readable page, not a blank screen.
    expect(response.body, contains('Signed in'));

    final redirect = await pending;
    expect(redirect.queryParameters['code'], 'abc123');
    expect(redirect.queryParameters['state'], 'xyz');
  });

  test('captures an error redirect and surfaces the reason', () async {
    final server = await LoopbackRedirectServer.start(port + 1);
    addTearDown(server.close);

    final pending = server.waitForRedirect();
    final response = await http.get(Uri.parse(
      'http://localhost:${port + 1}/callback'
      '?error=access_denied&error_description=User+said+no',
    ));

    expect(response.body, contains('Sign-in failed'));
    expect(response.body, contains('User said no'));
    expect((await pending).queryParameters['error'], 'access_denied');
  });

  test('ignores a favicon request and keeps waiting', () async {
    final server = await LoopbackRedirectServer.start(port + 2);
    addTearDown(server.close);

    final pending = server.waitForRedirect();
    final favicon =
        await http.get(Uri.parse('http://localhost:${port + 2}/favicon.ico'));
    expect(favicon.statusCode, 404);

    // Still listening: the real redirect arrives afterwards and is captured.
    await http.get(
      Uri.parse('http://localhost:${port + 2}/callback?code=later&state=s'),
    );
    expect((await pending).queryParameters['code'], 'later');
  });

  test('times out rather than hanging forever', () async {
    final server = await LoopbackRedirectServer.start(port + 3);
    addTearDown(server.close);

    await expectLater(
      server.waitForRedirect(timeout: const Duration(milliseconds: 200)),
      throwsA(isA<Exception>()),
    );
  });

  test('reports a clear error when the port is already taken', () async {
    final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, port + 4);
    addTearDown(blocker.close);

    await expectLater(
      LoopbackRedirectServer.start(port + 4),
      throwsA(isA<LoopbackBindException>()),
    );
  });

  test('closing an in-flight login unwinds it instead of parking it', () async {
    // Tapping Connect, backing out, and tapping Connect again must work: the
    // first attempt has to release the port and stop waiting.
    final first = await LoopbackRedirectServer.start(port + 5);
    // Attach the expectation before closing, or the error lands with no
    // listener and the zone reports it as unhandled.
    final pending = expectLater(
      first.waitForRedirect(),
      throwsA(isA<LoginAbandonedException>()),
    );

    await first.close();
    await pending;

    // The port is free again for the retry.
    final second = await LoopbackRedirectServer.start(port + 5);
    addTearDown(second.close);
    expect(second, isNotNull);
  });

  test('closing an unawaited server raises no unhandled error', () async {
    // Starting a listener and closing it without ever waiting must stay quiet;
    // erroring a future nobody listens to is an unhandled async error.
    final server = await LoopbackRedirectServer.start(port + 6);
    await server.close();

    // Nothing to assert beyond reaching here without the zone reporting.
    final reopened = await LoopbackRedirectServer.start(port + 6);
    addTearDown(reopened.close);
  });

  test('the default redirect URI is one Dexcom will accept', () {
    final uri = Uri.parse(DexcomAuth.defaultRedirectUri);
    // The portal rejects custom schemes; it takes only http/https.
    expect(uri.isScheme('http') || uri.isScheme('https'), isTrue);
    // A loopback host keeps the code off the network entirely.
    expect(uri.host, anyOf('localhost', '127.0.0.1'));
    // The port is part of the registered URI, so it must be explicit.
    expect(uri.hasPort, isTrue);
    expect(uri.port, 8423);
  });
}
