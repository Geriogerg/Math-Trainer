import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testUserId = '11111111-1111-4111-8111-111111111111';
const testEmail = 'joueur@test.com';

/// JWT non signé mais bien formé : gotrue lit `exp` dans la charge utile
/// (`Session.expiresAt`) sans jamais vérifier la signature côté client.
String _fakeAccessToken() {
  String encode(Map<String, Object> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.'
      '${encode({'sub': testUserId, 'exp': exp, 'role': 'authenticated'})}.'
      'signature';
}

Map<String, Object?> _sessionJson() => {
  'access_token': _fakeAccessToken(),
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh-token',
  'user': {
    'id': testUserId,
    'email': testEmail,
    'aud': 'authenticated',
    'app_metadata': <String, Object>{},
    'user_metadata': <String, Object>{},
    'created_at': '2026-11-17T00:00:00Z',
  },
};

/// Un vrai `SupabaseClient` (même code que l'app) dont seul le transport HTTP
/// est simulé : connexion et déconnexion répondent comme Supabase Auth, et
/// [restHandler] répond aux requêtes PostgREST (`/rest/v1/...`). Chaque
/// requête PostgREST reçue est ajoutée à [restRequests]. [authHandler], s'il
/// est fourni, remplace les réponses d'Auth (connexion, inscription) — pour
/// simuler un refus du serveur ou une panne réseau (lever une exception).
class SupabaseTestClient {
  SupabaseTestClient({
    Future<http.Response> Function(http.Request request)? restHandler,
    Future<http.Response> Function(http.Request request)? authHandler,
  }) {
    client = SupabaseClient(
      'https://test-project.supabase.co',
      'sb_publishable_test',
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (authHandler != null &&
            (path == '/auth/v1/token' || path == '/auth/v1/signup')) {
          return authHandler(request);
        }
        if (path == '/auth/v1/token') {
          return http.Response(
            jsonEncode(_sessionJson()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/auth/v1/logout') return http.Response('', 204);
        if (path.startsWith('/rest/v1/') && restHandler != null) {
          restRequests.add(request);
          final response = await restHandler(request);
          // PostgREST lit `response.request` pour choisir comment décoder le
          // corps — un `MockClient` ne le renseigne pas de lui-même.
          return http.Response.bytes(
            response.bodyBytes,
            response.statusCode,
            headers: response.headers,
            request: request,
          );
        }
        return http.Response('non simulé : ${request.method} $path', 500);
      }),
      // `implicit` : le flux PKCE par défaut exige un stockage pour le
      // vérificateur de code dès `signUp` (l'app l'obtient de
      // `Supabase.initialize`). Seul le lien de confirmation par email en
      // dépend — hors du champ de ces tests.
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }

  late final SupabaseClient client;
  final restRequests = <http.Request>[];

  /// Reproduit ce que `Supabase.initialize` fait au démarrage de l'app sans
  /// session persistée : un événement `initialSession` sans session, qui
  /// reste ensuite en tête de l'historique rejoué par `onAuthStateChange`.
  void emitInitialSessionWithoutUser() {
    // ignore: invalid_use_of_internal_member
    client.auth.notifyAllSubscribers(AuthChangeEvent.initialSession);
  }

  Future<void> signIn() => client.auth.signInWithPassword(
    email: testEmail,
    password: 'mot-de-passe',
  );
}
