import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/tiers/tiered_game_generator.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/history.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/item_of.dart';
import 'package:math_core/weak_spots/scheduler.dart';
import 'package:test/test.dart';

final _sevenEight = factOf(
  ArithmeticExercise(
    operandA: 7,
    operandB: 8,
    operationType: OperationType.multiplication,
  ),
)!;
final _other = Item.parse('fact:addition:7,8');
const _skill = SkillItem(PatternFamily.differenceOfSquares);

GradedAnswer _a(Item item, Grade grade) => (item: item, grade: grade);

/// The games in which [item] is due, among the first [games], when it is
/// answered fluently every time it is due — and [first] is a miss.
List<int> _dueGames(Item item, int games) {
  var schedule = WeakSpotSchedule.empty.afterGame([_a(item, Grade.miss)]);
  final due = <int>[];
  while (schedule.games < games) {
    if (schedule.isDue(item)) {
      due.add(schedule.games);
      schedule = schedule.afterGame([_a(item, Grade.fluent)]);
    } else {
      schedule = schedule.afterGame(const []);
    }
  }
  return due;
}

void main() {
  group('five boxes, counted in games (plan v3.5)', () {
    test('a missed 7 × 8 comes back within the next games until answered '
        'fluently three times (the exit test)', () {
      // Missed in game 0: box 1, due in game 1; fluent → box 2, due 2
      // games later (3); fluent → box 3, 4 later (7); fluent → box 4: 8
      // games later (15), out of the next games.
      expect(_dueGames(_sevenEight, 15), [1, 3, 7]);
      expect(_dueGames(_sevenEight, 40), [1, 3, 7, 15, 31]);
    });

    test('box b is due again after 1, 2, 4, 8, 16 games', () {
      for (var box = 1; box <= 5; box++) {
        // Into box `box` at game box − 1.
        var schedule = WeakSpotSchedule.empty.afterGame([
          _a(_skill, Grade.miss),
        ]);
        for (var up = 1; up < box; up++) {
          schedule = schedule.afterGame([_a(_skill, Grade.fluent)]);
        }
        expect(schedule.stateOf(_skill), ItemState(box, box - 1));
        final interval = boxIntervals[box - 1];
        for (var wait = 1; wait < interval; wait++) {
          expect(schedule.isDue(_skill), isFalse, reason: 'box $box +$wait');
          schedule = schedule.afterGame(const []);
        }
        expect(schedule.isDue(_skill), isTrue, reason: 'box $box');
      }
    });

    test('a miss sends any box back to 1; a slow answer keeps the box and '
        'restarts its wait', () {
      var schedule = WeakSpotSchedule.replay([
        [_a(_sevenEight, Grade.miss)],
        [_a(_sevenEight, Grade.fluent)],
        [_a(_sevenEight, Grade.fluent)],
        [_a(_sevenEight, Grade.fluent)],
      ]);
      expect(schedule.stateOf(_sevenEight), const ItemState(4, 3));
      schedule = schedule.afterGame([_a(_sevenEight, Grade.slow)]);
      expect(schedule.stateOf(_sevenEight), const ItemState(4, 4));
      schedule = schedule.afterGame([_a(_sevenEight, Grade.miss)]);
      expect(schedule.stateOf(_sevenEight), const ItemState(1, 5));
      expect(schedule.isDue(_sevenEight), isTrue);
    });

    test('fluent in box 5: mastered, out until a new miss', () {
      var schedule = WeakSpotSchedule.replay([
        [_a(_skill, Grade.miss)],
        for (var i = 0; i < 4; i++) [_a(_skill, Grade.fluent)],
      ]);
      expect(schedule.stateOf(_skill)!.box, 5);
      schedule = schedule.afterGame([_a(_skill, Grade.fluent)]);
      expect(schedule.stateOf(_skill), isNull);
      expect(schedule.tracked, isEmpty);
      schedule = schedule.afterGame([_a(_skill, Grade.miss)]);
      expect(schedule.stateOf(_skill), ItemState(1, schedule.games - 1));
    });

    test('correct answers to an untracked item leave it untracked', () {
      final schedule = WeakSpotSchedule.replay([
        [_a(_other, Grade.fluent), _a(_other, Grade.slow)],
        [_a(_other, Grade.slow)],
      ]);
      expect(schedule.tracked, isEmpty);
      expect(schedule.games, 2);
    });

    test('absence never punishes: an overdue item stays due, in its box', () {
      var schedule = WeakSpotSchedule.replay([
        [_a(_sevenEight, Grade.miss)],
        [_a(_sevenEight, Grade.fluent)],
      ]);
      for (var i = 0; i < 50; i++) {
        schedule = schedule.afterGame(const []);
      }
      expect(schedule.isDue(_sevenEight), isTrue);
      expect(schedule.stateOf(_sevenEight)!.box, 2);
    });

    test('answers within one game apply in order', () {
      final missedThenFluent = WeakSpotSchedule.empty.afterGame([
        _a(_other, Grade.miss),
        _a(_other, Grade.fluent),
      ]);
      expect(missedThenFluent.stateOf(_other), const ItemState(2, 0));
      final fluentThenMissed = WeakSpotSchedule.empty.afterGame([
        _a(_other, Grade.fluent),
        _a(_other, Grade.miss),
      ]);
      expect(fluentThenMissed.stateOf(_other), const ItemState(1, 0));
    });

    test('due items, the most urgent first: lowest box, most overdue, '
        'key', () {
      final b = Item.parse('fact:multiplication:6,9');
      final c = Item.parse('fact:multiplication:3,4');
      final schedule = WeakSpotSchedule.replay([
        [_a(_skill, Grade.miss)], // game 0
        [_a(_skill, Grade.fluent), _a(b, Grade.miss)], // skill box 2
        [_a(_sevenEight, Grade.miss), _a(c, Grade.miss)], // game 2
        [],
        [],
      ]);
      // Game 5: b box 1 (4 overdue), 7 × 8 and c box 1 (2 overdue, by
      // key: "3,4" < "7,8"), the skill box 2 (2 overdue).
      expect(schedule.due, [b, c, _sevenEight, _skill]);
    });

    test('a replay is the games one after the other', () {
      final random = Random(3);
      final items = [_sevenEight, _other, _skill];
      final history = [
        for (var g = 0; g < 60; g++)
          [
            for (var i = 0; i < random.nextInt(4); i++)
              _a(
                items[random.nextInt(items.length)],
                Grade.values[random.nextInt(Grade.values.length)],
              ),
          ],
      ];
      var stepwise = WeakSpotSchedule.empty;
      for (final game in history) {
        stepwise = stepwise.afterGame(game);
      }
      final replayed = WeakSpotSchedule.replay(history);
      expect(replayed.games, stepwise.games);
      expect(replayed.tracked, stepwise.tracked);
      expect(replayed.due, stepwise.due);
    });
  });

  group('recomputed from stored answers', () {
    test('a fact is fluent within its home tier\'s time, wherever asked; a '
        'skill within its game\'s', () {
      // 7 × 8: T1, 4 s, even asked in a T6 game.
      expect(
        itemFluentMs(
          _sevenEight,
          drawnAt: Level.whole(65),
          rules: RulesVersion.v6,
        ),
        4000,
      );
      // 12 × 7: T2, 6 s.
      expect(
        itemFluentMs(
          Item.parse('fact:multiplication:7,12'),
          drawnAt: Level.whole(45),
          rules: RulesVersion.v6,
        ),
        6000,
      );
      // Difference of squares at T6: 12 s; at T5: 10 s.
      expect(
        itemFluentMs(_skill, drawnAt: Level.whole(65), rules: RulesVersion.v6),
        12000,
      );
      expect(
        itemFluentMs(_skill, drawnAt: Level.whole(55), rules: RulesVersion.v6),
        10000,
      );
    });

    PersistedSession session(
      String id, {
      required int seed,
      required Map<ExerciseType, Level> levels,
      required DateTime at,
      RulesVersion rules = RulesVersion.v6,
    }) {
      final sequence = shuffledTypeSequence(
        types: levels.keys.toSet(),
        perOperation: 10,
        seed: seed,
      );
      return PersistedSession(
        id: id,
        playerId: 'p',
        seed: seed,
        enabledTypes: levels.keys.toSet(),
        exerciseCount: sequence.length,
        totalScore: 0,
        levels: levels,
        createdAt: at,
        typeSequence: sequence,
        rulesVersion: rules,
      );
    }

    PersistedAnswer answer(
      PersistedSession s,
      int i,
      Exercise exercise, {
      required bool correct,
      required int ms,
    }) {
      final d = describeExerciseForStorage(exercise);
      return PersistedAnswer(
        id: '${s.id}-$i',
        sessionId: s.id,
        exerciseType: d.exerciseType,
        operationType: d.operationType,
        operands: d.operands,
        submittedValue: correct ? exercise.correctAnswer : -1,
        isCorrect: correct,
        elapsedMs: ms,
        createdAt: s.createdAt,
      );
    }

    test('a game\'s answers: facts, families from the replay, grades', () {
      final s = session(
        'g1',
        seed: 42,
        levels: {ExerciseType.multiplication: Level.whole(55)},
        at: DateTime.utc(2026, 11, 24),
      );
      final generator =
          gameExerciseGenerator(
                rulesVersion: s.rulesVersion,
                enabledTypes: s.enabledTypes,
                levels: s.levels,
                typeSequence: s.typeSequence!,
              )
              as TieredGameGenerator;
      final random = Random(s.seed);
      final questions = <(Exercise, PatternFamily?)>[
        for (var i = 0; i < 10; i++)
          (generator.next(random), generator.lastFamily),
      ];
      // Every other one missed, the rest answered in 1 s.
      final answers = [
        for (final (i, (q, _)) in questions.indexed)
          answer(s, i, q, correct: i.isOdd, ms: 1000),
      ];
      final graded = gradedAnswersOf((session: s, answers: answers));
      final expected = [
        for (final (i, (q, family)) in questions.indexed)
          if (itemOf(q, family: family) case final item?)
            (item: item, grade: i.isOdd ? Grade.fluent : Grade.miss),
      ];
      expect(graded, expected);
      expect(
        questions.any((q) => q.$2 != null),
        isTrue,
        reason: 'T5 multiplication draws pattern questions',
      );
    });

    test('the schedule follows the games\' own time order', () {
      final early = session(
        'b-early',
        seed: 1,
        levels: {ExerciseType.multiplication: Level.whole(15)},
        at: DateTime.utc(2026, 11, 20),
      );
      final late = session(
        'a-late',
        seed: 2,
        levels: {ExerciseType.multiplication: Level.whole(15)},
        at: DateTime.utc(2026, 11, 21),
      );
      final seven = ArithmeticExercise(
        operandA: 8,
        operandB: 7,
        operationType: OperationType.multiplication,
      );
      // Not each game's real question: the replay then gives no family,
      // and 8 × 7 is a fact anyway.
      final missed = (
        session: early,
        answers: [answer(early, 0, seven, correct: false, ms: 30000)],
      );
      final fluent = (
        session: late,
        answers: [answer(late, 0, seven, correct: true, ms: 2000)],
      );
      final schedule = scheduleFromHistory([fluent, missed]);
      expect(schedule.games, 2);
      expect(schedule.stateOf(_sevenEight), const ItemState(2, 1));
    });

    test('a game of retired rules counts, its questions standard', () {
      final old = session(
        'v1',
        seed: 5,
        levels: {ExerciseType.multiplication: Level.whole(15)},
        at: DateTime.utc(2026, 11, 1),
        rules: RulesVersion.v1,
      );
      final seven = ArithmeticExercise(
        operandA: 7,
        operandB: 8,
        operationType: OperationType.multiplication,
      );
      final schedule = scheduleFromHistory([
        (
          session: old,
          answers: [answer(old, 0, seven, correct: false, ms: 5000)],
        ),
      ]);
      expect(schedule.stateOf(_sevenEight), const ItemState(1, 0));
    });
  });
}
