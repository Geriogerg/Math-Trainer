import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_trainer/core/errors/error_reporter.dart';
import 'package:math_trainer/infrastructure/backend/http_error_reporter.dart';

/// Phase 6c commit 5 (plan v4.1): what went wrong, to our own server.
void main() {
  test('the kind, the message, the top of the stack, the version — once '
      'each, at most 10 a run, failures swallowed', () async {
    final sent = <Map<String, Object?>>[];
    var fail = false;
    final reporter = HttpErrorReporter(
      serverUrl: Uri.parse('https://server.example'),
      appVersion: 'abc1234',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://server.example/v1/errors');
        expect(request.headers['authorization'], isNull, reason: 'no account');
        if (fail) throw http.ClientException('offline');
        sent.add((jsonDecode(request.body) as Map).cast<String, Object?>());
        return http.Response('{"status":"received"}', 202);
      }),
    );
    final stack = StackTrace.fromString(
      [for (var i = 0; i < 100; i++) '#$i frame'].join('\n'),
    );
    reporter.report(ErrorKind.flutter, StateError('broken'), stack);
    await reporter.pending;
    expect(sent.single['kind'], 'flutter');
    expect(sent.single['message'], 'Bad state: broken');
    expect(sent.single['appVersion'], 'abc1234');
    expect((sent.single['stack']! as String).split('\n'), hasLength(40));

    reporter.report(ErrorKind.flutter, StateError('broken'), stack);
    await reporter.pending;
    expect(sent, hasLength(1), reason: 'the same error once a run');

    fail = true;
    reporter.report(ErrorKind.zone, 'offline one', null);
    await reporter.pending; // swallowed
    fail = false;
    for (var i = 0; i < 20; i++) {
      reporter.report(ErrorKind.zone, 'error $i', null);
      await reporter.pending;
    }
    expect(sent.length, HttpErrorReporter.maxPerRun - 1, reason: 'capped');
  });

  test('installErrorReporting: Flutter\'s errors reported, still shown', () {
    final reported = <(ErrorKind, Object)>[];
    final previous = FlutterError.onError;
    var shown = 0;
    FlutterError.onError = (_) => shown++;
    addTearDown(() => FlutterError.onError = previous);
    installErrorReporting(_Recorder(reported));
    FlutterError.onError!(FlutterErrorDetails(exception: StateError('layout')));
    expect(reported.single.$1, ErrorKind.flutter);
    expect(shown, 1);
  });
}

class _Recorder implements ErrorReporter {
  _Recorder(this.reported);

  final List<(ErrorKind, Object)> reported;

  @override
  void report(ErrorKind kind, Object error, StackTrace? stack) =>
      reported.add((kind, error));
}
