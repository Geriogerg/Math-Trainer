import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_tables_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const store = SharedPreferencesTablesStore();

  test('setup: null until saved, then the same', () async {
    expect(await store.loadSetup(), isNull);
    final setup = TablesSetup(firstTable: 12, lastTable: 19, questions: 50);
    await store.saveSetup(setup);
    expect(await store.loadSetup(), setup);
  });

  test('a setup this build does not offer: the default (null)', () async {
    SharedPreferences.setMockInitialValues({
      'tables_first': 1,
      'tables_last': 60,
      'tables_max_multiplier': 10,
      'tables_questions': 10,
    });
    expect(await store.loadSetup(), isNull);
  });

  test('stats: none until saved, then the same; unreadable: none', () async {
    expect(await store.loadStats(), TablesStats.none);
    final stats = TablesStats.none.record([
      AnswerResult(
        exercise: const ArithmeticExercise(
          operandA: 7,
          operandB: 8,
          operationType: OperationType.multiplication,
        ),
        submittedValue: 56,
        isCorrect: true,
        elapsedMs: 1500,
        answeredAt: DateTime.utc(2026, 11, 23),
      ),
    ]);
    await store.saveStats(stats);
    expect(await store.loadStats(), stats);
    SharedPreferences.setMockInitialValues({'tables_stats': '{broken'});
    expect(await store.loadStats(), TablesStats.none);
  });
}
