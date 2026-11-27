import 'package:flutter/foundation.dart';

/// Where an error came from (stored names: the server keeps them).
enum ErrorKind {
  /// Flutter's own (`FlutterError.onError`): a build, layout or paint.
  flutter,

  /// Anything uncaught elsewhere (`PlatformDispatcher.onError`).
  zone,

  /// The start failed (`main`'s catch-all).
  start,
}

/// Sends what went wrong in the app to our own server (Phase 6c commit 5,
/// plan v4.1): fire and forget, never throws, never blocks the game.
abstract interface class ErrorReporter {
  void report(ErrorKind kind, Object error, StackTrace? stack);
}

/// No server to send to (a build without `SERVER_URL`, tests).
class NoErrorReporter implements ErrorReporter {
  const NoErrorReporter();

  @override
  void report(ErrorKind kind, Object error, StackTrace? stack) {}
}

/// Hooks [reporter] into Flutter's and the platform's error handlers;
/// what they did before still happens (the console keeps its messages).
void installErrorReporting(ErrorReporter reporter) {
  final presentFlutterError = FlutterError.onError;
  FlutterError.onError = (details) {
    reporter.report(ErrorKind.flutter, details.exception, details.stack);
    presentFlutterError?.call(details);
  };
  final platformError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.report(ErrorKind.zone, error, stack);
    return platformError?.call(error, stack) ?? false;
  };
}
