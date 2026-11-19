import 'package:math_core/validation/session_validation.dart';

/// Why a game is not on the leaderboard, in the player's words (Phase 3a
/// commit 2). [reason] is a stored `RejectionReason` name
/// (`PersistedSession.uploadRefused`); an unknown one (a newer server) gets
/// the generic sentence.
String uploadRefusalText(String reason) {
  final known = RejectionReason.values
      .where((r) => r.name == reason)
      .firstOrNull;
  return switch (known) {
    RejectionReason.levelsMismatch =>
      'Not ranked: it started from levels the server did not have (another '
          'device, or an older version of the app). Your next games use the '
          'server’s levels.',
    RejectionReason.placementAfterGames =>
      'Not ranked: a placement only counts before your first game.',
    RejectionReason.notReplayable =>
      'Not ranked: played before the app could send games to the server.',
    RejectionReason.outOfOrder =>
      'Not ranked: it reached the server after a newer game.',
    RejectionReason.wrongPlayer ||
    RejectionReason.futureTimestamp ||
    RejectionReason.badAnswerCount ||
    RejectionReason.questionMismatch ||
    RejectionReason.correctnessMismatch ||
    RejectionReason.badElapsed ||
    null => 'Not ranked: the server could not check this game.',
  };
}
