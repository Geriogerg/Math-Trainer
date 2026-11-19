import 'package:math_core/account/beta_access.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Two keys: the code this browser was let in with, and the player it was
/// tied to. Cleared browser storage asks for the code again — like any
/// first visit.
class SharedPreferencesBetaCodeStore implements BetaCodeStore {
  const SharedPreferencesBetaCodeStore();

  static const _codeKey = 'beta_code';
  static const _redeemedForKey = 'beta_code_redeemed_for';

  @override
  Future<String?> acceptedCode() async =>
      (await SharedPreferences.getInstance()).getString(_codeKey);

  @override
  Future<void> saveAcceptedCode(String code) async =>
      (await SharedPreferences.getInstance()).setString(_codeKey, code);

  @override
  Future<String?> redeemedFor() async =>
      (await SharedPreferences.getInstance()).getString(_redeemedForKey);

  @override
  Future<void> markRedeemedFor(String playerId) async =>
      (await SharedPreferences.getInstance()).setString(
        _redeemedForKey,
        playerId,
      );
}
