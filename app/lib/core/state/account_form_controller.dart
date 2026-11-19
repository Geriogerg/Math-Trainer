import 'package:flutter/foundation.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';

/// Longest player name — the `profiles.display_name` check constraint
/// (`supabase/profiles.sql`).
const maxDisplayNameLength = 30;

/// A problem found before anything is sent.
enum AccountFormProblem { missingFields, nameTooLong }

enum SaveProgressOutcome {
  /// Email and password linked, player name saved.
  saved,

  /// Linked (the progress is safe), but the name could not be saved — the
  /// player can set it again from Profile.
  savedWithoutName,

  /// The project requires email confirmation: linked once the link in the
  /// email is opened (Phase 6; off until then).
  confirmationPending,

  /// Nothing changed; see [AccountFormController.failure] or
  /// [AccountFormController.problem].
  failed,
}

/// The account forms of Profile (plan, section 6.3): a guest saves their
/// progress (email, password, player name), or signs in to an existing
/// account. Holds the submit logic and its state; the screens only render
/// it (rule 7).
class AccountFormController extends ChangeNotifier {
  AccountFormController({required this.accounts, required this.profiles});

  final AccountRepository accounts;
  final ProfileRepository profiles;

  bool _isSubmitting = false;
  AccountFailure? _failure;
  String? _failureDetail;
  AccountFormProblem? _problem;

  bool get isSubmitting => _isSubmitting;

  /// Server-side reason of the last failure, `null` otherwise.
  AccountFailure? get failure => _failure;
  String? get failureDetail => _failureDetail;

  /// Client-side reason of the last failure, `null` otherwise.
  AccountFormProblem? get problem => _problem;

  /// Links [email] and [password] to the signed-in guest (same account id,
  /// so nothing moves), then saves [displayName]. Email trimmed: mobile
  /// keyboards often append a space.
  Future<SaveProgressOutcome> saveProgress({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (!_begin(
      email.trim().isEmpty || password.isEmpty || name.isEmpty
          ? AccountFormProblem.missingFields
          : name.length > maxDisplayNameLength
          ? AccountFormProblem.nameTooLong
          : null,
    )) {
      return SaveProgressOutcome.failed;
    }
    try {
      final account = await accounts.linkEmail(
        email: email.trim(),
        password: password,
      );
      if (account == null) {
        _end();
        return SaveProgressOutcome.confirmationPending;
      }
    } on AccountException catch (e) {
      _end(e);
      return SaveProgressOutcome.failed;
    }
    try {
      await profiles.updateDisplayName(name);
    } catch (_) {
      _end();
      return SaveProgressOutcome.savedWithoutName;
    }
    _end();
    return SaveProgressOutcome.saved;
  }

  /// Signs in to an existing account. For a guest this replaces the guest
  /// on this browser (their games stay on the device, unshown, never
  /// merged) — the screen warns before calling it. `true` on success.
  Future<bool> signIn({required String email, required String password}) async {
    if (!_begin(
      email.trim().isEmpty || password.isEmpty
          ? AccountFormProblem.missingFields
          : null,
    )) {
      return false;
    }
    try {
      await accounts.signIn(email: email.trim(), password: password);
    } on AccountException catch (e) {
      _end(e);
      return false;
    }
    _end();
    return true;
  }

  /// `false` (and the problem shown) if [problem] is set; otherwise marks
  /// the form submitting.
  bool _begin(AccountFormProblem? problem) {
    _problem = problem;
    _failure = null;
    _failureDetail = null;
    _isSubmitting = problem == null;
    notifyListeners();
    return problem == null;
  }

  void _end([AccountException? error]) {
    _isSubmitting = false;
    _failure = error?.failure;
    _failureDetail = error?.detail;
    notifyListeners();
  }
}
