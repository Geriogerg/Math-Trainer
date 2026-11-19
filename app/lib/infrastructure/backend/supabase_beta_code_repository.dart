import 'package:math_core/account/beta_access.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The beta gate's two SQL functions (`…_beta_codes.sql`): a status check
/// that needs no session, and the redeem by the new guest.
class SupabaseBetaCodeRepository implements BetaCodeRepository {
  SupabaseBetaCodeRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<BetaCodeStatus> status(String code) async =>
      BetaCodeStatus.values.byName(await _call('beta_code_status', code));

  @override
  Future<BetaRedeemResult> redeem(String code) async =>
      BetaRedeemResult.values.byName(await _call('redeem_beta_code', code));

  Future<String> _call(String function, String code) async {
    final Object? answer;
    try {
      answer = await _client.rpc(function, params: {'p_code': code});
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
    if (answer is! String) {
      throw FormatException('$function answered $answer');
    }
    return answer;
  }
}
