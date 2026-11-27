import 'package:math_core/tiers/fluent_time.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/level_cache_orchestrator.dart';
import 'package:math_core/leveling/level_updates.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:test/test.dart';

final _at = DateTime.utc(2026, 11, 23, 9);

AnswerResult _answer(
  OperationType op, {
  required bool correct,
  required int ms,
}) => AnswerResult(
  exercise: ArithmeticExercise(operandA: 3, operandB: 1, operationType: op),
  submittedValue: correct ? (op == OperationType.addition ? 4 : 3) : 0,
  isCorrect: correct,
  elapsedMs: ms,
  answeredAt: _at,
);

void main() {
  final fluent = fluentTimeMs(
    ExerciseType.addition,
    Level.zero,
    RulesVersion.v3,
  );
  final outcomes = [
    for (var i = 0; i < 4; i++) ...[
      _answer(OperationType.addition, correct: true, ms: fluent),
      _answer(OperationType.multiplication, correct: true, ms: fluent + 5000),
    ],
  ];

  test('each operation moves by its own quality, from 0 (v2)', () {
    final updates = gameLevelUpdates(
      outcomes: outcomes,
      frozenLevels: {
        ExerciseType.addition: Level.zero,
        ExerciseType.multiplication: Level.whole(10),
      },
      priorLevels: {
        ExerciseType.multiplication: LevelCacheEntry(
          level: Level.whole(10),
          sessionsPlayed: 2,
          updatedAt: DateTime.utc(2026, 11, 22),
        ),
      },
      now: _at,
      rulesVersion: RulesVersion.v2,
      typeSequence: [for (final o in outcomes) o.exercise.type],
    );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
    expect(updates[ExerciseType.addition]!.sessionsPlayed, 1);
    // All slow: q = 0.75, +1.2 — never a calibration or return boost.
    expect(
      updates[ExerciseType.multiplication]!.level,
      Level.fromHundredths(1120),
    );
    expect(updates[ExerciseType.multiplication]!.sessionsPlayed, 3);
    expect(updates[ExerciseType.multiplication]!.updatedAt, _at);
  });

  test('a missing frozen level counts as 0', () {
    final updates = gameLevelUpdates(
      outcomes: outcomes,
      frozenLevels: const {},
      priorLevels: const {},
      now: _at,
      rulesVersion: RulesVersion.v2,
      typeSequence: [for (final o in outcomes) o.exercise.type],
    );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
    expect(
      updates[ExerciseType.multiplication]!.level,
      Level.fromHundredths(120),
    );
  });

  test("each session under its own rules: the same answers, all slow, give "
      '+1.2 under v2 and +1.56 under v3; v1 is retired', () {
    Level? multiplication(RulesVersion version) => gameLevelUpdates(
      outcomes: outcomes,
      frozenLevels: const {},
      priorLevels: const {},
      now: _at,
      rulesVersion: version,
      typeSequence: [for (final o in outcomes) o.exercise.type],
    )[ExerciseType.multiplication]?.level;
    expect(multiplication(RulesVersion.v2), Level.fromHundredths(120));
    expect(multiplication(RulesVersion.v3), Level.fromHundredths(156));
    expect(() => multiplication(RulesVersion.v1), throwsArgumentError);
  });

  // Rules v9: a quit counts its missing questions (`doc/levels.md` v1.6).
  group('rules v9: quitting counts', () {
    final planned = [
      ...List.filled(4, ExerciseType.addition),
      ...List.filled(4, ExerciseType.multiplication),
    ];
    Map<ExerciseType, Level> after(List<AnswerResult> answered) => {
      for (final MapEntry(:key, :value) in gameLevelUpdates(
        outcomes: answered,
        frozenLevels: {
          ExerciseType.addition: Level.whole(30),
          ExerciseType.multiplication: Level.whole(30),
        },
        priorLevels: const {},
        now: _at,
        rulesVersion: RulesVersion.v9,
        typeSequence: planned,
      ).entries)
        key: value.level,
    };
    AnswerResult add() =>
        _answer(OperationType.addition, correct: true, ms: fluent);

    test('the unanswered questions are timeouts: 2 of 4 fluent, then a quit, '
        'is q = 0.50 (−1.03)', () {
      expect(
        after([add(), add()])[ExerciseType.addition],
        Level.fromHundredths(3000 - 103),
      );
    });

    test('an operation with no answer at all loses the full cap', () {
      expect(after([add()])[ExerciseType.multiplication], Level.whole(27));
    });

    test('a finished game moves as under v8', () {
      final all = [
        for (var i = 0; i < 4; i++) add(),
        for (var i = 0; i < 4; i++)
          _answer(OperationType.multiplication, correct: true, ms: fluent),
      ];
      final v8 = gameLevelUpdates(
        outcomes: all,
        frozenLevels: {
          ExerciseType.addition: Level.whole(30),
          ExerciseType.multiplication: Level.whole(30),
        },
        priorLevels: const {},
        now: _at,
        rulesVersion: RulesVersion.v8,
        typeSequence: planned,
      );
      expect(after(all), {for (final e in v8.entries) e.key: e.value.level});
    });

    // Phase 6b commit 4: what the result screen says about each change.
    test('gameQualities: the quality behind each change, its zone, the '
        'questions left', () {
      final q = gameQualities(
        outcomes: [add(), add()],
        frozenLevels: {
          ExerciseType.addition: Level.whole(30),
          ExerciseType.multiplication: Level.whole(30),
        },
        rulesVersion: RulesVersion.v9,
        typeSequence: planned,
      );
      expect(q[ExerciseType.addition], (
        questions: 4,
        unanswered: 2,
        right: 2,
        fast: 2,
        zone: QualityZone.down,
      ));
      expect(q[ExerciseType.multiplication]!.unanswered, 4);
      // Finished, all fluent: up; three fluent and a slow one: 96 %, up.
      final finished = gameQualities(
        outcomes: [
          for (var i = 0; i < 3; i++) add(),
          _answer(OperationType.addition, correct: true, ms: 20000),
        ],
        frozenLevels: {ExerciseType.addition: Level.whole(30)},
        rulesVersion: RulesVersion.v9,
        typeSequence: List.filled(4, ExerciseType.addition),
      )[ExerciseType.addition]!;
      // 96 % of the credit, but counts on screen: 4 right, 3 fast.
      expect(
        (finished.right, finished.fast, finished.zone),
        (4, 3, QualityZone.up),
      );
    });

    test('more answers of an operation than planned throw (rule 13)', () {
      expect(
        () => after([for (var i = 0; i < 5; i++) add()]),
        throwsArgumentError,
      );
    });
  });

  test('the orchestrator scores a game with them, under its rules', () async {
    final repository = InMemorySessionRepository();
    final updates = await const LevelCacheOrchestrator().computeUpdates(
      outcomes: outcomes,
      frozenLevels: const {
        ExerciseType.addition: Level.zero,
        ExerciseType.multiplication: Level.zero,
      },
      repository: repository,
      playerId: 'p',
      now: _at,
      rulesVersion: RulesVersion.v3,
      typeSequence: [for (final o in outcomes) o.exercise.type],
    );
    expect(updates[ExerciseType.addition]!.level, Level.fromHundredths(300));
    expect(
      updates[ExerciseType.multiplication]!.level,
      Level.fromHundredths(156),
    );
  });
}
