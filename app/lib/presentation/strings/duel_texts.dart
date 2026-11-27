import 'package:math_core/duel/duel_client.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_rating.dart';
import 'package:math_core/duel/duel_run.dart';

import '../number_format.dart';
import 'strings.dart';

/// Duels left unfinished on this device, sent when the app came back
/// (Phase 6b commit 5): said once.
String unfinishedDuelsSentText(List<DuelMode> modes) =>
    strings.labels.unfinishedDuelsSent(
      modes.length == 1 ? duelModeLabel(modes.single) : null,
      modes.length,
    );

/// The modes as the Online tab names them (`doc/mockups/online.html`).
String duelModeLabel(DuelMode mode) => strings.labels.duelMode(mode);

/// A rating as shown: whole points, grouped ("1 542"), " ?" while
/// provisional (plan v3.7: the first 10 rated duels).
String ratingText(double rating, {required bool provisional}) =>
    '${groupedNumber(ratingPoints(rating))}${provisional ? ' ?' : ''}';

/// The opponent's lane label: their name, "Practice" for a simulated
/// opponent (plan v3.7), "Player" for a player with no public name.
String opponentLabel(DuelOffer offer) => switch (offer.opponent) {
  null => strings.labels.practiceOpponent,
  final o => o.name ?? strings.labels.unnamedPlayer,
};

/// Won / Lost / Draw, from the player's Glicko score.
String resultWord(double result) => strings.labels.result(result);

/// A score's headline: "7 / 8" (questions) or "3" (distance to the
/// targets), and its time in whole seconds.
({String value, String time}) scoreTexts(DuelScore score) => (
  value: score.mode.isQuiz ? '${score.points} / 8' : '${score.points}',
  time: '${(score.totalMs / 1000).round()} s',
);
