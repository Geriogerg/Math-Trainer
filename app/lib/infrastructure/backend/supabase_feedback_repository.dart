import 'package:math_core/feedback/feedback.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// `send_feedback()` (`…_feedback.sql`): the signed-in player's message,
/// trimmed and stored with the app version.
class SupabaseFeedbackRepository implements FeedbackRepository {
  SupabaseFeedbackRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<FeedbackOutcome> send({
    required String message,
    required String appVersion,
  }) async {
    final Object? answer;
    try {
      answer = await _client.rpc(
        'send_feedback',
        params: {'p_message': message, 'p_app_version': appVersion},
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
    if (answer is! String) throw FormatException('send_feedback: $answer');
    return FeedbackOutcome.values.byName(answer);
  }
}
