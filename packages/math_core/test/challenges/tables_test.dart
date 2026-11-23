import 'package:math_core/challenges/tables.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:test/test.dart';

void main() {
  group('TablesSetup', () {
    test(
      'a range within 1–50; multipliers 10 or 20; 10, 20 or 50 questions',
      () {
        expect(TablesSetup(firstTable: 12, lastTable: 19).lastTable, 19);
        expect(TablesSetup(firstTable: 50, lastTable: 50).firstTable, 50);
        for (final bad in [
          () => TablesSetup(firstTable: 0),
          () => TablesSetup(lastTable: 51),
          () => TablesSetup(firstTable: 9, lastTable: 8),
          () => TablesSetup(maxMultiplier: 12),
          () => TablesSetup(questions: 15),
        ]) {
          expect(bad, throwsArgumentError);
        }
      },
    );
  });

  group('tablesQuestions', () {
    test('table × multiplier, both in their ranges, as many as asked', () {
      for (final setup in [
        TablesSetup(firstTable: 12, lastTable: 19, questions: 50),
        TablesSetup(firstTable: 1, lastTable: 50, maxMultiplier: 20),
        TablesSetup(firstTable: 7, lastTable: 7, questions: 10),
      ]) {
        final questions = tablesQuestions(seed: 3, setup: setup);
        expect(questions, hasLength(setup.questions));
        for (final q in questions) {
          expect(q.operationType, OperationType.multiplication);
          expect(
            q.operandA,
            inInclusiveRange(setup.firstTable, setup.lastTable),
          );
          expect(q.operandB, inInclusiveRange(1, setup.maxMultiplier));
        }
      }
    });

    test('every fact once before any comes back', () {
      // Table 7 × 1–10: 10 facts; 20 questions are two full passes.
      final questions = tablesQuestions(
        seed: 11,
        setup: TablesSetup(firstTable: 7, lastTable: 7, questions: 20),
      );
      expect(questions.take(10).map((q) => q.operandB).toSet(), hasLength(10));
      expect(questions.skip(10).map((q) => q.operandB).toSet(), hasLength(10));
    });

    test('shuffled by the seed: same seed, same round; another, another', () {
      final setup = TablesSetup(firstTable: 2, lastTable: 12);
      expect(
        tablesQuestions(seed: 5, setup: setup),
        tablesQuestions(seed: 5, setup: setup),
      );
      expect(
        tablesQuestions(seed: 6, setup: setup),
        isNot(tablesQuestions(seed: 5, setup: setup)),
      );
    });

    test('pinned on VM and JavaScript', () {
      final round = tablesQuestions(
        seed: 2026,
        setup: TablesSetup(firstTable: 12, lastTable: 19, questions: 10),
      );
      expect([for (final q in round) '${q.operandA}x${q.operandB}'], _pinned);
    });
  });

  group('TablesStats', () {
    AnswerResult answer(int t, int m, {required bool right, int ms = 2000}) =>
        AnswerResult(
          exercise: ArithmeticExercise(
            operandA: t,
            operandB: m,
            operationType: OperationType.multiplication,
          ),
          submittedValue: right ? t * m : 0,
          isCorrect: right,
          elapsedMs: ms,
          answeredAt: DateTime.utc(2026, 11, 23),
        );

    test('a round adds a game, its answers, and each fact\'s record', () {
      final stats = TablesStats.none
          .record([
            answer(7, 8, right: true, ms: 4000),
            answer(6, 7, right: false, ms: 9000),
            answer(7, 8, right: true, ms: 2000),
          ])
          .record([answer(12, 12, right: true, ms: 1000)]);
      expect(stats.games, 2);
      expect(stats.answers, 4);
      expect(stats.right, 3);
      expect(
        stats.facts['7x8'],
        const FactRecord(asked: 2, right: 2, totalMs: 6000),
      );
      expect(
        [for (final f in stats.slowest(2)) '${f.table}x${f.multiplier}'],
        ['6x7', '7x8'],
      );
    });

    test('a non-table answer is refused (rule 13)', () {
      expect(
        () => TablesStats.none.record([
          AnswerResult(
            exercise: const ArithmeticExercise(
              operandA: 1,
              operandB: 1,
              operationType: OperationType.addition,
            ),
            submittedValue: 2,
            isCorrect: true,
            elapsedMs: 1,
            answeredAt: DateTime.utc(2026),
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('JSON round-trip; anything else refused', () {
      final stats = TablesStats.none.record([
        answer(7, 8, right: true),
        answer(13, 4, right: false),
      ]);
      expect(TablesStats.fromJson(stats.toJson()), stats);
      for (final bad in <Object?>[
        null,
        {'games': 1},
        {'games': -1, 'answers': 0, 'right': 0, 'facts': {}},
        {
          'games': 1,
          'answers': 1,
          'right': 1,
          'facts': {
            '7x8': [1, 1],
          },
        },
      ]) {
        expect(() => TablesStats.fromJson(bad), throwsFormatException);
      }
    });
  });
}

/// Recorded on the VM (Levels phase commit 6).
const _pinned = <String>[
  '16x3',
  '14x1',
  '18x1',
  '13x5',
  '18x10',
  '12x6',
  '16x4',
  '15x5',
  '19x8',
  '12x7',
];
