import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/sync/session_upload_client.dart';
import 'package:math_trainer/infrastructure/backend/http_session_upload_client.dart';

void main() {
  final upload = SessionUpload(
    session: PersistedSession(
      id: 's1',
      playerId: 'p1',
      seed: 1,
      enabledTypes: const {ExerciseType.addition},
      exerciseCount: 1,
      totalScore: 0,
      levels: {ExerciseType.addition: Level.zero},
      createdAt: DateTime.utc(2026, 11, 20),
      typeSequence: const [ExerciseType.addition],
    ),
    answers: const [],
  );

  HttpSessionUploadClient clientAnswering(
    http.Response Function(http.Request request) answer, {
    String? token = 'jwt',
  }) => HttpSessionUploadClient(
    serverUrl: Uri.parse('https://server.example'),
    accessToken: () async => token,
    client: MockClient((request) async => answer(request)),
  );

  http.Response json(int status, Object body) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('posts the upload with the bearer token; accepted', () async {
    late http.Request sent;
    final outcome = await clientAnswering((request) {
      sent = request;
      return json(200, {
        'status': 'accepted',
        'syncedAt': '2026-11-20T10:00:00+00:00',
        'duplicate': true,
      });
    }).upload(upload);

    expect(sent.url.toString(), 'https://server.example/v1/sessions');
    expect(sent.headers['authorization'], 'Bearer jwt');
    expect(jsonDecode(sent.body), upload.toJson());
    expect(outcome, isA<UploadAccepted>());
    final accepted = outcome as UploadAccepted;
    expect(accepted.syncedAt, DateTime.utc(2026, 11, 20, 10));
    expect(accepted.syncedAt.isUtc, isTrue);
    expect(accepted.duplicate, isTrue);
  });

  test('refused, with the server levels when it sends them', () async {
    final outcome = await clientAnswering(
      (_) => json(409, {
        'status': 'refused',
        'reason': 'levelsMismatch',
        'levels': {
          'addition': {
            'level': 1234,
            'sessionsPlayed': 2,
            'updatedAt': '2026-11-19T00:00:00.000Z',
          },
        },
      }),
    ).upload(upload);
    final refused = outcome as UploadRefused;
    expect(refused.reason, 'levelsMismatch');
    expect(
      refused.serverLevels![ExerciseType.addition]!.level,
      Level.fromHundredths(1234),
    );
  });

  test('everything else may pass: unavailable, retried later', () async {
    Future<void> expectUnavailable(HttpSessionUploadClient client) =>
        expectLater(client.upload(upload), throwsA(isA<UploadUnavailable>()));

    await expectUnavailable(
      clientAnswering((_) => json(401, {'error': 'unauthorized'})),
    );
    await expectUnavailable(
      clientAnswering((_) => json(503, {'error': 'unavailable'})),
    );
    // The server-side beta gate (Phase 5.1): kept and retried, never
    // recorded as refused — a code redeemed later lets it through.
    await expectUnavailable(
      clientAnswering((_) => json(403, {'error': 'beta_code_required'})),
    );
    await expectUnavailable(
      clientAnswering((_) => http.Response('<html>waking up</html>', 502)),
    );
    await expectUnavailable(
      clientAnswering((_) => throw http.ClientException('offline')),
    );
    // Signed out: not even sent.
    var called = false;
    await expectUnavailable(
      clientAnswering((_) {
        called = true;
        return json(200, {});
      }, token: null),
    );
    expect(called, isFalse);
  });
}
