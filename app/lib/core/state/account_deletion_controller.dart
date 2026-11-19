import 'package:flutter/foundation.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/persistence/session_repository.dart';

enum AccountDeletionOutcome {
  /// Server account and local data deleted, signed out: `AuthGate` creates
  /// a fresh guest.
  deleted,

  /// Server account deleted and signed out, but the local wipe failed —
  /// the data stays on this device under an id nobody can use any more.
  deletedButLocalDataKept,

  /// Nothing deleted (server refused or unreachable); see
  /// [AccountDeletionController.failure].
  failed,
}

/// In-app account deletion, guests included (plan, section 6.3): the
/// account on the server first — if that fails, nothing else is touched —
/// then this player's local data, then a local sign-out, after which the
/// gate starts a fresh guest.
class AccountDeletionController extends ChangeNotifier {
  AccountDeletionController({
    required this.accounts,
    required this.repository,
    required this.playerId,
  });

  final AccountRepository accounts;
  final SessionRepository repository;

  /// The account id: local rows are stored under it.
  final String playerId;

  bool _isDeleting = false;
  AccountFailure? _failure;
  String? _failureDetail;

  bool get isDeleting => _isDeleting;
  AccountFailure? get failure => _failure;
  String? get failureDetail => _failureDetail;

  Future<AccountDeletionOutcome> delete() async {
    _isDeleting = true;
    _failure = null;
    _failureDetail = null;
    notifyListeners();
    try {
      await accounts.deleteAccount();
    } on AccountException catch (e) {
      _isDeleting = false;
      _failure = e.failure;
      _failureDetail = e.detail;
      notifyListeners();
      return AccountDeletionOutcome.failed;
    }
    var outcome = AccountDeletionOutcome.deleted;
    try {
      await repository.deletePlayerData(playerId);
    } on Exception catch (_) {
      // The account is gone already: go on and sign out rather than leave
      // the player on a dead session; the outcome says what stayed.
      outcome = AccountDeletionOutcome.deletedButLocalDataKept;
    }
    await accounts.signOut();
    _isDeleting = false;
    notifyListeners();
    return outcome;
  }
}
