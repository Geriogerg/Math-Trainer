import 'dart:convert';

import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:test/test.dart';

/// Phase 7 commit 1: the server regenerates a duel's content from its
/// stored config alone (JSON, as stored in `duels.config`) — the same
/// questions and rounds the app's core draws (pinned in math_core's
/// `duel_config_test.dart`).
void main() {
  test('a stored Basics config replays to the pinned questions', () {
    final stored = jsonDecode(
      '{"mode":"basics","seed":1,"difficulty":4,"rules":8,"duelRules":1}',
    );
    final questions = DuelConfig.fromJson(stored).questions();
    final first = describeExerciseForStorage(questions.first);
    expect(first.operationType, 'addition');
    expect(first.operands.values, [7216, 681]);
    expect(questions.last.correctAnswer, 17050);
  });

  test('a stored Get the count config replays to the pinned rounds', () {
    final stored = jsonDecode(
      '{"mode":"count","seed":987654321,"difficulty":2,"rules":8,'
      '"duelRules":1}',
    );
    final rounds = DuelConfig.fromJson(stored).rounds();
    expect([for (final (p, _) in rounds) p.target], [442, 847, 205]);
  });
}
