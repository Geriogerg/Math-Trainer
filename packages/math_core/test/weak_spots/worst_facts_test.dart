import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/worst_facts.dart';
import 'package:test/test.dart';

PersistedAnswer _a(int a, int b, {required bool right, int ms = 2000}) =>
    PersistedAnswer(
      id: '$a-$b-$right-$ms',
      sessionId: 'g',
      exerciseType: 'arithmetic',
      operationType: 'multiplication',
      operands: {'operandA': a, 'operandB': b},
      submittedValue: right ? a * b : -1,
      isCorrect: right,
      elapsedMs: ms,
      createdAt: DateTime.utc(2026, 11, 25),
    );

void main() {
  final session = PersistedSession(
    id: 'g',
    playerId: 'p',
    seed: 1,
    enabledTypes: {ExerciseType.multiplication},
    exerciseCount: 30,
    totalScore: 0,
    levels: {ExerciseType.multiplication: Level.whole(15)},
    createdAt: DateTime.utc(2026, 11, 25),
  );

  test('most missed first (rate, then count), then the slowest; fluent '
      'never-missed facts and single answers left out', () {
    final records = worstFacts([
      (
        session: session,
        answers: [
          // 7 × 8: 2 of 2 missed, asked in both orders.
          _a(7, 8, right: false), _a(8, 7, right: false),
          // 6 × 9: 1 of 2 missed.
          _a(6, 9, right: false), _a(9, 6, right: true),
          // 3 × 4: 2 of 4 missed — same rate, more misses: before 6 × 9.
          _a(3, 4, right: false), _a(4, 3, right: false),
          _a(3, 4, right: true), _a(3, 4, right: true),
          // 6 × 7: never missed, 8 s on average (T1's fluent time: 4 s).
          _a(6, 7, right: true, ms: 8000), _a(7, 6, right: true, ms: 8000),
          // 6 × 8: never missed, 5 s: slow, less so.
          _a(6, 8, right: true, ms: 5000), _a(6, 8, right: true, ms: 5000),
          // 2 × 3: fluent, never missed: no weak spot.
          _a(2, 3, right: true, ms: 1000), _a(2, 3, right: true, ms: 1000),
          // 9 × 9: once only.
          _a(9, 9, right: false),
          // 17 × 46: no fact.
          _a(17, 46, right: false), _a(17, 46, right: false),
        ],
      ),
    ]);
    expect(
      [for (final r in records) r.fact.key],
      [
        'fact:multiplication:7,8',
        'fact:multiplication:3,4',
        'fact:multiplication:6,9',
        'fact:multiplication:6,7',
        'fact:multiplication:6,8',
      ],
    );
    expect(records.first.misses, 2);
    expect(records[3].meanCorrectMs, 8000);
    expect(records[3].fluentMs, 4000);
    expect(records.first.fact, Item.parse('fact:multiplication:7,8'));
  });

  test('at most five', () {
    final answers = [
      for (var b = 1; b <= 10; b++) ...[
        _a(6, b, right: false),
        _a(6, b, right: false),
      ],
    ];
    expect(worstFacts([(session: session, answers: answers)]), hasLength(5));
  });
}
