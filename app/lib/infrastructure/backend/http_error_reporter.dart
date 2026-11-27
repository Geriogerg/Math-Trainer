import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/error_reporter.dart';

/// `POST /v1/errors` on the Dart server (Phase 6c commit 5): the kind, the
/// message and the top of the stack, the build's version — no account, no
/// token. The same error is sent once per run of the app, and at most
/// [maxPerRun] in all: a loop of failures sends a handful, not thousands.
/// Failures are swallowed — reporting must never be an error of its own.
class HttpErrorReporter implements ErrorReporter {
  HttpErrorReporter({
    required this.serverUrl,
    required this.appVersion,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final Uri serverUrl;
  final String appVersion;
  final http.Client _client;

  static const maxPerRun = 10;

  final _sent = <String>{};

  /// What is in flight (tests await it).
  Future<void> pending = Future.value();

  @override
  void report(ErrorKind kind, Object error, StackTrace? stack) {
    final message = '$error';
    final key = '${kind.name} $message';
    if (_sent.length >= maxPerRun || !_sent.add(key)) return;
    final lines = (stack?.toString() ?? '').split('\n');
    final body = jsonEncode({
      'kind': kind.name,
      'message': message.length > 1000 ? message.substring(0, 1000) : message,
      'stack': lines.take(40).join('\n'),
      'appVersion': appVersion,
    });
    pending = _client
        .post(
          serverUrl.resolve('/v1/errors'),
          headers: {'content-type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 15))
        .then<void>((_) {}, onError: (Object _) {});
  }
}
