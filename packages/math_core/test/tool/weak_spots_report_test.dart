@TestOn('vm')
library;

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:test/test.dart';

import '../../tool/src/weak_spots_report.dart';

StoredGame _game(String id, int day, List<(int, int, bool, int)> answers) {
  final session = PersistedSession(
    id: id,
    playerId: 'player-1234567890',
    seed: 1,
    enabledTypes: {ExerciseType.multiplication},
    exerciseCount: answers.length,
    totalScore: 0,
    levels: {ExerciseType.multiplication: Level.whole(15)},
    createdAt: DateTime.utc(2026, 11, day),
  );
  return (
    session: session,
    answers: [
      for (final (i, (a, b, right, ms)) in answers.indexed)
        PersistedAnswer(
          id: '$id-$i',
          sessionId: id,
          exerciseType: 'arithmetic',
          operationType: 'multiplication',
          operands: {'operandA': a, 'operandB': b},
          submittedValue: right ? a * b : -1,
          isCorrect: right,
          elapsedMs: ms,
          createdAt: session.createdAt,
        ),
    ],
  );
}

void main() {
  test('before and after the first miss; never-scheduled items apart; '
      'boxes now', () {
    final reports = weakSpotsReport({
      'player-1234567890': [
        // 7 × 8 right slowly, then missed (enters), then fluent twice.
        _game('g1', 1, [(7, 8, true, 6000), (6, 7, true, 2000)]),
        _game('g2', 2, [(8, 7, false, 3000)]),
        _game('g3', 3, [(7, 8, true, 2000), (6, 7, true, 3000)]),
        _game('g4', 5, [(7, 8, true, 1000)]),
      ],
    });
    final r = reports.single;
    expect(r.games, 4);
    expect(r.scheduled, {Item.parse('fact:multiplication:7,8')});
    // Before: the slow right answer and the miss.
    expect(r.before.answers, 2);
    expect(r.before.right, 1);
    expect(r.after.answers, 2);
    expect(r.after.rightPercent, 100);
    expect(r.after.medianRightMs, 2000);
    // 6 × 7, never missed.
    expect(r.never.answers, 2);
    // Missed, then fluent twice: box 3.
    expect(r.outOfBoxOne, 1);
    expect(r.mastered, 0);
    final text = formatWeakSpotsReport(reports);
    expect(text, contains('player-1'));
    expect(text, isNot(contains('player-1234567890')));
    expect(text, contains('regression to the mean'));
    expect(text, contains('ALL'));
  });
}
