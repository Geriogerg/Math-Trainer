/// Math Trainer's server (plan, Phase 2).
library;

import 'package:shelf/shelf.dart';

import 'src/config.dart';
import 'src/duel_endpoint.dart';
import 'src/http_app.dart';
import 'src/session_endpoint.dart';
import 'src/supabase_gateway.dart';

export 'src/config.dart';
export 'src/duel_endpoint.dart';
export 'src/rating/glicko2.dart';
export 'src/http_app.dart'
    show buildHandler, jsonResponse, originAllowed, Route;
export 'src/session_endpoint.dart';
export 'src/supabase_gateway.dart';

/// The production handler: every route, wired to the real Supabase.
Handler buildServerHandler(ServerConfig config) {
  final gateway = HttpSupabaseGateway(config);
  return buildHandler(
    config,
    routes: [
      SessionEndpoint(gateway, requireBetaCode: config.requireBetaCode).route,
      ...DuelEndpoint(gateway).routes,
    ],
  );
}
