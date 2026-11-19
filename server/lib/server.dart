/// Math Trainer's server (plan, Phase 2).
library;

import 'package:shelf/shelf.dart';

import 'src/config.dart';
import 'src/http_app.dart';

export 'src/config.dart';
export 'src/http_app.dart' show buildHandler, jsonResponse;

/// The production handler: every route, wired to the real Supabase.
Handler buildServerHandler(ServerConfig config) => buildHandler(config);
