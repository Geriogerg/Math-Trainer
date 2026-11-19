/// Math Trainer's server (plan, Phase 2).
library;

import 'package:shelf/shelf.dart';

import 'src/config.dart';
import 'src/http_app.dart';
import 'src/session_endpoint.dart';
import 'src/supabase_gateway.dart';

export 'src/config.dart';
export 'src/http_app.dart' show buildHandler, jsonResponse, Route;
export 'src/session_endpoint.dart';
export 'src/supabase_gateway.dart';

/// The production handler: every route, wired to the real Supabase.
Handler buildServerHandler(ServerConfig config) => buildHandler(
  config,
  routes: [SessionEndpoint(HttpSupabaseGateway(config)).route],
);
