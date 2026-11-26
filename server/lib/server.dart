/// Math Trainer's server (plan, Phase 2).
library;

import 'dart:async';

import 'package:shelf/shelf.dart';

import 'src/config.dart';
import 'src/duel_endpoint.dart';
import 'src/http_app.dart';
import 'src/rate_limit.dart';
import 'src/session_endpoint.dart';
import 'src/supabase_gateway.dart';

export 'src/config.dart';
export 'src/duel_endpoint.dart';
export 'src/rating/duel_rating_update.dart';
export 'src/rating/glicko2.dart';
export 'src/http_app.dart'
    show buildHandler, jsonResponse, originAllowed, readBodyWithin, Route;
export 'src/rate_limit.dart';
export 'src/session_endpoint.dart';
export 'src/supabase_gateway.dart';

/// The production handler: every route, wired to the real Supabase (or to
/// [gateway]), behind the rate limits. Abandoned duels are recorded every
/// [sweepEvery] (and soon after a duel request), outside the requests.
Handler buildServerHandler(
  ServerConfig config, {
  SupabaseGateway? gateway,
  Duration sweepEvery = const Duration(minutes: 5),
}) {
  final supabase = gateway ?? HttpSupabaseGateway(config);
  final limits = RateLimits();
  final duels = DuelEndpoint(supabase, limits: limits, sweepInRequests: false);
  Timer.periodic(sweepEvery, (_) => duels.sweepSoon());
  return buildHandler(
    config,
    limits: limits,
    routes: [
      SessionEndpoint(
        supabase,
        requireBetaCode: config.requireBetaCode,
        limits: limits,
      ).route,
      ...duels.routes,
    ],
  );
}
