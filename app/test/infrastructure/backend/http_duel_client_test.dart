import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_trainer/infrastructure/backend/http_duel_client.dart';

void main() {
  // Plan v4.1, deploy-window duels: every request for a duel says which
  // rules this build can play; the server refuses a build older than its
  // own (`appOutdated`), a refusal the screen turns into "Reload".
  test('find and open declare the rules this build knows', () async {
    final bodies = <String, Map<String, Object?>>{};
    final client = HttpDuelClient(
      serverUrl: Uri.parse('https://server.example'),
      accessToken: () async => 'token',
      client: MockClient((request) async {
        bodies[request.url.path] = (jsonDecode(request.body) as Map)
            .cast<String, Object?>();
        return http.Response(
          jsonEncode({'status': 'refused', 'reason': 'appOutdated'}),
          409,
        );
      }),
    );
    await expectLater(
      client.find(DuelMode.basics),
      throwsA(
        isA<DuelRefused>().having((e) => e.reason, 'reason', 'appOutdated'),
      ),
    );
    await expectLater(client.open('d1'), throwsA(isA<DuelRefused>()));
    for (final path in ['/v1/duels', '/v1/duels/open']) {
      final body = bodies[path]!;
      expect(body['rules'], [
        for (final v in RulesVersion.replayed) v.number,
      ], reason: path);
      expect(body['duelRules'], [
        for (final v in DuelRulesVersion.replayed) v.number,
      ], reason: path);
      expect(knowsCurrentDuelRules(body), isTrue, reason: path);
    }
    expect(bodies['/v1/duels']!['mode'], 'basics');
    expect(bodies['/v1/duels/open']!['duelId'], 'd1');
  });
}
