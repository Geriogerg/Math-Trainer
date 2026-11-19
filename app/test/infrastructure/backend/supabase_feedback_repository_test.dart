import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:math_core/feedback/feedback.dart';
import 'package:math_trainer/infrastructure/backend/supabase_feedback_repository.dart';

import 'supabase_test_client.dart';

void main() {
  test('calls send_feedback with the message and version', () async {
    final bodies = <String>[];
    final supabase = SupabaseTestClient(
      restHandler: (request) async {
        bodies.add('${request.url.path} ${request.body}');
        return http.Response(
          jsonEncode('tooMany'),
          200,
          headers: {'content-type': 'application/json'},
        );
      },
    );
    addTearDown(supabase.client.dispose);
    await supabase.signIn();

    final outcome = await SupabaseFeedbackRepository(
      supabase.client,
    ).send(message: 'Hi', appVersion: 'a1b2c3d');

    expect(outcome, FeedbackOutcome.tooMany);
    expect(bodies, [
      '/rest/v1/rpc/send_feedback {"p_message":"Hi","p_app_version":"a1b2c3d"}',
    ]);
  });

  test('a server error throws (the screen offers to try again)', () async {
    final supabase = SupabaseTestClient(
      restHandler: (request) async => http.Response(
        jsonEncode({'message': 'boom'}),
        500,
        headers: {'content-type': 'application/json'},
      ),
    );
    addTearDown(supabase.client.dispose);
    await supabase.signIn();
    await expectLater(
      SupabaseFeedbackRepository(
        supabase.client,
      ).send(message: 'Hi', appVersion: 'x'),
      throwsA(isA<Exception>()),
    );
  });
}
