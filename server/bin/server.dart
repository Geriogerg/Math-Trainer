import 'dart:io';

import 'package:math_trainer_server/server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Entry point: configuration from the environment, then serve. The
/// container (`server/Dockerfile`) runs the AOT-compiled binary of this file.
Future<void> main() async {
  final ServerConfig config;
  try {
    config = ServerConfig.fromEnvironment(Platform.environment);
  } on ArgumentError catch (error) {
    stderr.writeln('Configuration error: ${error.message}');
    exitCode = 64; // EX_USAGE
    return;
  }
  final server = await shelf_io.serve(
    buildServerHandler(config),
    InternetAddress.anyIPv4,
    config.port,
  );
  // The config prints without its secret key.
  stdout.writeln('Listening on :${server.port} — $config');
}
