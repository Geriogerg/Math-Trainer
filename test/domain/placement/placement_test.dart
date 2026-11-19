import 'package:math_trainer/core/domain/leveling/level.dart';
import 'package:math_trainer/core/domain/leveling/leveling_rules.dart';
import 'package:math_trainer/core/domain/models/answer_result.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/session_kind.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/placement/placement.dart';
import 'package:math_trainer/core/domain/placement/placement_exercise_source.dart';
import 'package:math_trainer/core/domain/placement/placement_level_orchestrator.dart';
import 'package:test/test.dart';

const _rules = placementRulesV1;

PlacementAnswer _pass() => (isCorrect: true, elapsedMs: 1000);
PlacementAnswer _fail() => (isCorrect: false, elapsedMs: 15000);

void main() {
  group('Staircase', () {
    test('starts at the start level with the first step', () {
      final s = Staircase.start(_rules);
      expect(s.levelHundredths, _rules.startLevel * 100);
      expect(s.stepHundredths, _rules.firstStepHundredths);
      expect(s.level, Level.whole(_rules.startLevel));
    });

    test('up on a pass, down on a fail, the step halving each time', () {
      final up = Staircase.start(_rules).after(passed: true);
      expect(up.levelHundredths, 3500 + 2500);
      expect(up.stepHundredths, 1250);
      final down = up.after(passed: false);
      expect(down.levelHundredths, 6000 - 1250);
      expect(down.stepHundredths, 625);
    });

    test('never leaves [1, 100]', () {
      var low = Staircase.start(_rules);
      var high = Staircase.start(_rules);
      for (var i = 0; i < 6; i++) {
        low = low.after(passed: false);
        high = high.after(passed: true);
      }
      expect(low.level, Level.floor);
      expect(high.level.hundredths, lessThanOrEqualTo(10000));
    });
  });

  test('a pass is right and within the time limit', () {
    for (final rules in [placementRulesV1, placementRulesV2]) {
      for (final type in placementTypes) {
        bool passed(bool ok, int ms) => placementPassed(
          type: type,
          isCorrect: ok,
          elapsedMs: ms,
          rules: rules,
        );
        final limit = rules.passMaxElapsedMsFor(type);
        expect(passed(true, limit), isTrue);
        expect(passed(true, limit + 1), isFalse);
        expect(passed(false, 500), isFalse);
      }
    }
  });

  test('a non-placed operation has no pass time', () {
    expect(
      () => placementRulesV2.passMaxElapsedMsFor(ExerciseType.power),
      throwsArgumentError,
    );
  });

  group('version 2 (owner, end of Phase 1)', () {
    test('5 questions per operation, same start and step as v1', () {
      expect(placementRulesV2.questionsPerType, 5);
      expect(placementRulesV2.questionCount, 20);
      expect(placementRulesV2.startLevel, placementRulesV1.startLevel);
      expect(
        placementRulesV2.firstStepHundredths,
        placementRulesV1.firstStepHundredths,
      );
      expect(currentPlacementRules, same(placementRulesV2));
    });

    test('pass time per operation, 1.5 × t_rapide', () {
      expect(
        placementRulesV2.passMaxElapsedMsByType,
        placementPassTimesFor(LevelingRules()),
      );
    });

    test('v1 is unchanged: a flat 3 s, 6 questions per operation', () {
      expect(placementRulesV1.questionsPerType, 6);
      for (final type in placementTypes) {
        expect(placementRulesV1.passMaxElapsedMsFor(type), 3000);
      }
    });
  });

  test('a placement kind maps to its rules and back', () {
    expect(placementRulesFor(SessionKind.placementV1), same(placementRulesV1));
    expect(placementRulesFor(SessionKind.placementV2), same(placementRulesV2));
    expect(placementKindFor(placementRulesV1), SessionKind.placementV1);
    expect(placementKindFor(placementRulesV2), SessionKind.placementV2);
    expect(() => placementRulesFor(SessionKind.game), throwsArgumentError);
  });

  test('the four basic operations in turn', () {
    expect(
      [for (var i = 0; i < 8; i++) placementTypeAt(i)],
      [...placementTypes, ...placementTypes],
    );
  });

  group('placementLevels', () {
    test('all passed: start + every step (35 + 49.21)', () {
      final levels = placementLevels(
        List.generate(_rules.questionCount, (_) => _pass()),
        _rules,
      );
      // 2500 + 1250 + 625 + 312 + 156 + 78 = 4921 hundredths.
      for (final type in placementTypes) {
        expect(levels[type], Level.fromHundredths(8421));
      }
      expect(levels.keys, unorderedEquals(placementTypes));
    });

    test('all failed: the floor', () {
      final levels = placementLevels(
        List.generate(_rules.questionCount, (_) => _fail()),
        _rules,
      );
      expect(levels.values.toSet(), {Level.floor});
    });

    test('each operation follows its own answers', () {
      // Additions pass, the rest fail.
      final answers = [
        for (var i = 0; i < _rules.questionCount; i++)
          placementTypeAt(i) == ExerciseType.addition ? _pass() : _fail(),
      ];
      final levels = placementLevels(answers, _rules);
      expect(levels[ExerciseType.addition], Level.fromHundredths(8421));
      expect(levels[ExerciseType.division], Level.floor);
    });

    test('rejects an incomplete placement (no level from a partial one)', () {
      expect(
        () => placementLevels(
          List.generate(_rules.questionCount - 1, (_) => _pass()),
          _rules,
        ),
        throwsArgumentError,
      );
    });
  });

  group('PlacementExerciseSource', () {
    AnswerResult answerTo(Exercise e, PlacementAnswer a) => AnswerResult(
      exercise: e,
      submittedValue: a.isCorrect ? e.correctAnswer : e.correctAnswer + 1,
      isCorrect: a.isCorrect,
      elapsedMs: a.elapsedMs,
      answeredAt: DateTime.utc(2026, 11, 19),
    );

    List<Exercise> play(int seed, List<PlacementAnswer> answers) {
      final source = PlacementExerciseSource(seed: seed);
      return [
        for (final a in answers)
          (() {
            final e = source.next();
            source.onAnswered(answerTo(e, a));
            return e;
          })(),
      ];
    }

    final mixed = [
      for (var i = 0; i < _rules.questionCount; i++)
        i % 3 == 0 ? _fail() : _pass(),
    ];

    test('same seed and answers: same questions (rule 2)', () {
      expect(play(1763510400000, mixed), play(1763510400000, mixed));
    });

    test('equals the pure replay the server will run', () {
      expect(
        play(424242, mixed),
        replayPlacementQuestions(seed: 424242, answers: mixed),
      );
    });

    test('the answers steer the questions: harder after passes', () {
      int maxOperand(List<Exercise> xs) => xs
          .whereType<ArithmeticExercise>()
          .where((e) => e.operationType.name == 'addition')
          .map((e) => e.operandA > e.operandB ? e.operandA : e.operandB)
          .last;
      final allPass = List.generate(_rules.questionCount, (_) => _pass());
      final allFail = List.generate(_rules.questionCount, (_) => _fail());
      expect(
        maxOperand(play(7, allPass)),
        greaterThan(maxOperand(play(7, allFail))),
      );
    });

    test('rotates through the four operations', () {
      final types = play(3, mixed).map((e) => e.type).toList();
      expect(types.take(4), placementTypes);
    });

    test('asking twice without an answer is a bug, not a silent drift', () {
      final source = PlacementExerciseSource(seed: 1)..next();
      expect(source.next, throwsStateError);
    });
  });

  test('PlacementLevelOrchestrator: the four placed levels, sessionsPlayed '
      'from the rules, the others untouched', () async {
    final source = PlacementExerciseSource(seed: 9);
    final outcomes = <AnswerResult>[];
    for (var i = 0; i < _rules.questionCount; i++) {
      final e = source.next();
      final o = AnswerResult(
        exercise: e,
        submittedValue: e.correctAnswer,
        isCorrect: true,
        elapsedMs: 1000,
        answeredAt: DateTime.utc(2026, 11, 19),
      );
      source.onAnswered(o);
      outcomes.add(o);
    }
    final now = DateTime.utc(2026, 11, 19, 12);

    final updates = await const PlacementLevelOrchestrator(rules: _rules)
        .computeUpdates(
          outcomes: outcomes,
          frozenLevels: const {},
          repository: InMemorySessionRepository(),
          playerId: 'p',
          now: now,
        );

    expect(updates.keys, unorderedEquals(placementTypes));
    for (final entry in updates.values) {
      expect(entry.level, Level.fromHundredths(8421));
      expect(entry.sessionsPlayed, _rules.sessionsPlayedAfter);
      expect(entry.updatedAt, now);
    }
  });
}
