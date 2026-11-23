// Server-side gate probe (Phase 5.1 commit 5): what an outsider gets by
// calling the API directly, skipping the app's gate screen.
//
//   cd server
//   dart run tool/gate_probe.dart <server url> <supabase url> <publishable key>
//
// 1. creates an anonymous player on Supabase, with no invitation code;
// 2. posts a session for it straight to the server's /v1/sessions;
// 3. expects 403 `beta_code_required` (or 200 when the server's BETA_GATE
//    is false — it says which);
// 4. deletes the player (`delete_my_account`), whatever happened.
// Prints neither the key nor the player's tokens. Exit code 0 when the
// server answered as its own `/health` says it should.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/uuid.dart';
import 'package:math_core/sync/session_upload.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    stderr.writeln(
      'usage: dart run tool/gate_probe.dart <server url> <supabase url> '
      '<publishable key>',
    );
    exit(2);
  }
  final server = Uri.parse(args[0]);
  final supabase = Uri.parse(args[1]);
  final key = args[2];
  if (key.startsWith('sb_secret_')) {
    stderr.writeln('a publishable key, never the secret one');
    exit(2);
  }
  final client = http.Client();
  const wake = Duration(seconds: 120); // a sleeping free server wakes slowly

  final health = jsonDecode(
    (await client.get(server.resolve('/health')).timeout(wake)).body,
  );
  final gateOn = health['betaGate'] == true;
  stdout.writeln(
    'server ${health['version']}, beta gate ${gateOn ? 'on' : 'off'}',
  );

  final signup = await client.post(
    supabase.resolve('/auth/v1/signup'),
    headers: {'apikey': key, 'content-type': 'application/json'},
    body: '{}',
  );
  if (signup.statusCode != 200) {
    stderr.writeln('anonymous sign-up failed: HTTP ${signup.statusCode}');
    exit(1);
  }
  final session = jsonDecode(signup.body) as Map<String, Object?>;
  final token = session['access_token'] as String;
  final playerId = (session['user'] as Map)['id'] as String;
  stdout.writeln('anonymous player ${playerId.substring(0, 8)}…, no code');

  var ok = false;
  try {
    final upload = SessionUpload(
      session: PersistedSession(
        id: generateUuidV4(),
        playerId: playerId,
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 1,
        totalScore: 0,
        levels: {ExerciseType.addition: Level.zero},
        createdAt: DateTime.now().toUtc(),
        typeSequence: const [ExerciseType.addition],
        rulesVersion: RulesVersion.current,
      ),
      answers: const [],
    );
    final response = await client
        .post(
          server.resolve('/v1/sessions'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(upload.toJson()),
        )
        .timeout(wake);
    stdout.writeln(
      'direct upload: HTTP ${response.statusCode} ${response.body}',
    );
    ok = gateOn
        ? response.statusCode == 403 &&
              response.body.contains('beta_code_required')
        : response.statusCode != 403;
  } finally {
    final deleted = await client.post(
      supabase.resolve('/rest/v1/rpc/delete_my_account'),
      headers: {
        'apikey': key,
        'authorization': 'Bearer $token',
        'content-type': 'application/json',
      },
      body: '{}',
    );
    stdout.writeln(
      'player deleted: ${deleted.statusCode >= 200 && deleted.statusCode < 300 ? 'yes' : 'NO (HTTP ${deleted.statusCode}) — the 30-day cleanup will'}',
    );
    client.close();
  }
  stdout.writeln(ok ? 'PROBE PASSED' : 'PROBE FAILED');
  exit(ok ? 0 : 1);
}
