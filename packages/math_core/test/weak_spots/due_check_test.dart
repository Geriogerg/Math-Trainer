import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:test/test.dart';

const _mul = ExerciseType.multiplication;
final _level = Level.whole(15);
final _sevenEight = Item.parse('fact:multiplication:7,8');

PersistedAnswer _answer(PersistedSession s, int i, Exercise q, bool right) {
  final d = describeExerciseForStorage(q);
  return PersistedAnswer(
    id: '${s.id}-$i',
    sessionId: s.id,
    exerciseType: d.exerciseType,
    operationType: d.operationType,
    operands: d.operands,
    submittedValue: right ? q.correctAnswer : -1,
    isCorrect: right,
    elapsedMs: 1500 + 73 * i,
    createdAt: s.createdAt,
  );
}

/// A past game whose only answer missed 7 × 8.
StoredGame _missedSevenEight() {
  final s = PersistedSession(
    id: 'past',
    playerId: 'p',
    seed: 1,
    enabledTypes: {_mul},
    exerciseCount: 10,
    totalScore: 0,
    levels: {_mul: _level},
    createdAt: DateTime.utc(2026, 11, 24),
    typeSequence: List.filled(10, _mul),
    rulesVersion: RulesVersion.v8,
  );
  final q = ArithmeticExercise(
    operandA: 7,
    operandB: 8,
    operationType: OperationType.multiplication,
  );
  return (session: s, answers: [_answer(s, 0, q, false)]);
}

/// A complete v8 game at level 15 re-asking [weakSpots], answered right.
SessionUpload _game(
  List<Item> weakSpots, {
  SessionKind kind = SessionKind.game,
}) {
  final sequence = shuffledTypeSequence(
    types: {_mul},
    perOperation: 10,
    seed: 9,
  );
  final s = PersistedSession(
    id: 'now',
    playerId: 'p',
    seed: 9,
    enabledTypes: {_mul},
    exerciseCount: 10,
    totalScore: 0,
    levels: {_mul: _level},
    createdAt: DateTime.utc(2026, 11, 25),
    typeSequence: sequence,
    rulesVersion: RulesVersion.v8,
    weakSpots: weakSpots,
    kind: kind,
  );
  final g = gameExerciseGenerator(
    rulesVersion: RulesVersion.v8,
    enabledTypes: {_mul},
    levels: {_mul: _level},
    typeSequence: sequence,
    weakSpots: weakSpots,
  );
  final r = Random(9);
  return SessionUpload(
    session: s,
    answers: [for (var i = 0; i < 10; i++) _answer(s, i, g.next(r), true)],
  );
}

ValidationResult _validate(SessionUpload upload, List<StoredGame>? history) =>
    validateSessionUpload(
      upload: upload,
      callerId: 'p',
      state: ServerPlayerState(
        levels: {
          _mul: LevelCacheEntry(
            level: _level,
            sessionsPlayed: 1,
            updatedAt: DateTime.utc(2026, 11, 24),
          ),
        },
        lastSessionAt: DateTime.utc(2026, 11, 24),
      ),
      receivedAt: DateTime.utc(2026, 11, 26),
      history: history,
    );

void main() {
  test('weak spots due in the accepted history: accepted, no flag', () {
    final verdict = _validate(_game([_sevenEight]), [_missedSevenEight()]);
    expect(verdict, isA<Accepted>());
    expect((verdict as Accepted).flags, isEmpty);
    expect(verdict.levelUpdates, isNotEmpty);
  });

  test('not due: still accepted for levels, flagged', () {
    final verdict = _validate(_game([_sevenEight]), const []);
    expect(verdict, isA<Accepted>());
    final accepted = verdict as Accepted;
    expect(accepted.flags, {ValidationFlag.weakSpotsNotDue});
    expect(accepted.levelUpdates, isNotEmpty);
    expect(weakSpotsNotDue(_game([_sevenEight]).session, const []), [
      _sevenEight,
    ]);
  });

  test('no history given, or a game without weak spots: not checked', () {
    expect((_validate(_game([_sevenEight]), null) as Accepted).flags, isEmpty);
    expect(needsUploadHistory(_game(const []).session), isFalse);
    expect(needsUploadHistory(_game([_sevenEight]).session), isTrue);
  });
}
