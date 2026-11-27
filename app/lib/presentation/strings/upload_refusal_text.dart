import 'package:math_core/validation/session_validation.dart';

import 'strings.dart';

/// Why a game is not on the leaderboard, in the player's words (Phase 3a
/// commit 2). [reason] is a stored `RejectionReason` name
/// (`PersistedSession.uploadRefused`); an unknown one (a newer server) gets
/// the generic sentence.
String uploadRefusalText(String reason) => strings.labels.uploadRefusal(
  RejectionReason.values.where((r) => r.name == reason).firstOrNull,
);
