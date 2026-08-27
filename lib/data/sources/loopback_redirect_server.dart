import 'dart:async';
import 'dart:io';

/// Catches an OAuth redirect on the loopback interface.
///
/// Dexcom's developer portal only accepts `http://` or `https://` redirect
/// URIs — a custom scheme like `myapp://callback` is rejected outright. The
/// standard answer for a native app (RFC 8252 §7.3) is to redirect to
/// `http://localhost:<port>/<path>` and have the app itself listen there for
/// the few seconds the login takes.
///
/// The port cannot be chosen dynamically: Dexcom matches the redirect URI
/// exactly against the one registered in the portal, so it is fixed by
/// [DexcomAuth.defaultRedirectUri].
class LoopbackRedirectServer {
  LoopbackRedirectServer._(this._server, this._completer);

  final HttpServer _server;
  final Completer<Uri> _completer;

  /// Whether anyone is actually awaiting the redirect.
  ///
  /// Completing a future with an error that has no listener raises an
  /// unhandled async error, so [close] must only cancel a wait that exists.
  bool _awaited = false;

  /// Begin listening on [port]. Bind before opening the browser, so a redirect
  /// cannot arrive before there is anything to receive it.
  static Future<LoopbackRedirectServer> start(int port) async {
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException catch (e) {
      throw LoopbackBindException(port, e.osError?.message ?? e.message);
    }

    final completer = Completer<Uri>();
    final instance = LoopbackRedirectServer._(server, completer);

    server.listen(
      (request) async {
        // Browsers ask for a favicon on the same origin; answer and keep
        // waiting rather than treating it as the redirect.
        if (request.uri.path == '/favicon.ico') {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        final query = request.uri.queryParameters;
        final isRedirect =
            query.containsKey('code') || query.containsKey('error');

        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.html
          ..write(_page(
            success: query.containsKey('code'),
            detail: query['error_description'] ?? query['error'],
          ));
        await request.response.close();

        if (isRedirect && !completer.isCompleted) {
          completer.complete(request.uri);
        }
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    );

    return instance;
  }

  /// The redirect URI, or a timeout if the user never finishes signing in.
  Future<Uri> waitForRedirect({
    Duration timeout = const Duration(minutes: 5),
  }) {
    _awaited = true;
    return _completer.future.timeout(
        timeout,
      onTimeout: () => throw TimeoutException(
        'Timed out waiting for the Dexcom login to complete.',
      ),
    );
  }

  /// Stop listening.
  ///
  /// If a login was still in flight, its [waitForRedirect] future is completed
  /// with [LoginAbandonedException] rather than left parked until the timeout,
  /// so the abandoned attempt unwinds now instead of surfacing a stale error
  /// minutes later.
  Future<void> close() async {
    if (_awaited && !_completer.isCompleted) {
      _completer.completeError(LoginAbandonedException());
    }
    await _server.close(force: true);
  }

  static String _page({required bool success, String? detail}) {
    final title = success ? 'Signed in' : 'Sign-in failed';
    final body = success
        ? 'You can close this tab and return to Glucose Trends.'
        : 'Dexcom reported: ${detail ?? 'an unknown error'}';
    return '''
<!doctype html>
<html><head><meta charset="utf-8"><title>$title</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  body { font: 16px/1.5 system-ui, sans-serif; margin: 0;
         display: flex; align-items: center; justify-content: center;
         min-height: 100vh; background: #f5f6fa; color: #1a1c1e; }
  main { text-align: center; padding: 32px; max-width: 22rem; }
  h1 { font-size: 1.25rem; margin: 0 0 8px; }
  p { margin: 0; color: #5a5f66; }
</style></head>
<body><main><h1>$title</h1><p>$body</p></main></body></html>''';
  }
}

/// Raised when a login is superseded or cancelled before the redirect arrives.
///
/// Expected control flow, not a failure to report: the user simply started
/// again.
class LoginAbandonedException implements Exception {
  @override
  String toString() => 'Dexcom login was cancelled.';
}

class LoopbackBindException implements Exception {
  LoopbackBindException(this.port, this.reason);
  final int port;
  final String reason;

  @override
  String toString() =>
      'Could not listen on port $port for the Dexcom redirect ($reason). '
      'Close whatever is using that port, or register a different one in the '
      'Dexcom portal and update the redirect URI here to match.';
}
