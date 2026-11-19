import 'account.dart';

/// The invite-only beta's gate (plan v2.3, Phase 3a commit 3): a code is
/// asked once per device, before the anonymous sign-in, then tied to the
/// guest it created so each tester's data can be followed. Gone at the
/// public launch (Phase 6).

/// What the server says of a code typed on the gate screen. Names match
/// `beta_code_status()` (SQL).
enum BetaCodeStatus { ok, unknown, full, disabled }

/// What tying a code to the signed-in player did. Names match
/// `redeem_beta_code()` (SQL).
enum BetaRedeemResult { redeemed, already, unknown, full, disabled }

/// The codes, on the server. Both throw on network or server failure.
abstract interface class BetaCodeRepository {
  Future<BetaCodeStatus> status(String code);

  /// Ties [code] to the signed-in player.
  Future<BetaRedeemResult> redeem(String code);
}

/// The code this device was let in with, and the player it was tied to.
/// Concrete store in `infrastructure/` (rule 3).
abstract class BetaCodeStore {
  /// The code accepted on this device; `null` until the gate is passed.
  Future<String?> acceptedCode();

  Future<void> saveAcceptedCode(String code);

  /// The player the code was last tied to (or refused for, for good).
  Future<String?> redeemedFor();

  Future<void> markRedeemedFor(String playerId);
}

/// As the server compares codes: upper case, no spaces or dashes.
String normalizeBetaCode(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// After a sign-in: ties this device's code to a guest that has none yet.
/// Only guests — an email account was let in before, or predates the beta.
/// Settled answers (anything but a failure) are remembered, so a launch does
/// not ask twice; a failure is retried at the next sign-in. Returns `null`
/// when there was nothing to do or it failed.
Future<BetaRedeemResult?> redeemDeviceBetaCode({
  required BetaCodeStore store,
  required BetaCodeRepository codes,
  required Account account,
}) async {
  if (!account.isAnonymous) return null;
  final code = await store.acceptedCode();
  if (code == null || await store.redeemedFor() == account.id) return null;
  final BetaRedeemResult result;
  try {
    result = await codes.redeem(code);
  } on Exception catch (_) {
    return null;
  }
  await store.markRedeemedFor(account.id);
  return result;
}
