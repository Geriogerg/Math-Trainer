import '../challenges/count.dart';
import '../models/answer_result.dart';
import 'duel_config.dart';
import 'duel_mode.dart';

/// A player's run of a duel (plan v3.7, Phase 7 commit 2), as the app sends
/// it and the server replays it against the duel's config
/// (`validateDuelRun`). Only what was typed and when: correctness, scores
/// and lanes are always recomputed, never taken from the client.
sealed class DuelRun {
  const DuelRun();

  Map<String, Object?> toJson();

  /// Strict: anything missing or mistyped throws [FormatException]. The
  /// shape must match [mode] (answers for a question mode, rounds for Get
  /// the count); lengths and ranges are the validation's to check.
  static DuelRun fromJson(Object? json, DuelMode mode) {
    final root = _map(json, 'run');
    if (mode.isQuiz) {
      return QuizRun([
        for (final (i, raw) in _list(root, 'answers').indexed)
          () {
            final a = _map(raw, 'answers[$i]');
            return DuelAnswer(
              value: _int(a, 'value'),
              elapsedMs: _int(a, 'ms'),
            );
          }(),
      ]);
    }
    return CountRun([
      for (final (i, raw) in _list(root, 'rounds').indexed)
        CountRoundRun([
          for (final (j, imp) in _list(
            _map(raw, 'rounds[$i]'),
            'improvements',
          ).indexed)
            () {
              final m = _map(imp, 'improvements[$j]');
              return CountImprovement(
                atMs: _int(m, 'ms'),
                value: _int(m, 'value'),
                steps: [
                  for (final step in _list(m, 'steps')) _stepFromJson(step),
                ],
              );
            }(),
        ]),
    ]);
  }
}

final class DuelAnswer {
  const DuelAnswer({required this.value, required this.elapsedMs});

  /// The answer typed; [timeoutSubmittedValue] for none (a timeout, or a
  /// question left when the player quit), as in solo games.
  final int value;
  final int elapsedMs;

  /// A question never answered: the full 30 s.
  static const none = DuelAnswer(
    value: timeoutSubmittedValue,
    elapsedMs: 30000,
  );

  @override
  bool operator ==(Object other) =>
      other is DuelAnswer &&
      other.value == value &&
      other.elapsedMs == elapsedMs;

  @override
  int get hashCode => Object.hash(value, elapsedMs);
}

/// Basics or Advanced: the 8 answers, in question order.
final class QuizRun extends DuelRun {
  QuizRun(List<DuelAnswer> answers) : answers = List.unmodifiable(answers);

  final List<DuelAnswer> answers;

  /// The run so far, the questions left as [DuelAnswer.none]: what quitting
  /// sends (plan v3.7: quitting counts).
  QuizRun completedWithTimeouts() => QuizRun([
    ...answers,
    for (var i = answers.length; i < duelQuestionCount; i++) DuelAnswer.none,
  ]);

  @override
  Map<String, Object?> toJson() => {
    'answers': [
      for (final a in answers) {'value': a.value, 'ms': a.elapsedMs},
    ],
  };
}

/// One improvement of a Get the count round's closest value: when, the
/// value, and the operations that made it from the six numbers (so the
/// server can check it was reachable).
final class CountImprovement {
  CountImprovement({
    required this.atMs,
    required this.value,
    required List<CountStep> steps,
  }) : steps = List.unmodifiable(steps);

  final int atMs;
  final int value;
  final List<CountStep> steps;
}

final class CountRoundRun {
  CountRoundRun(List<CountImprovement> improvements)
    : improvements = List.unmodifiable(improvements);

  /// In time order, each strictly closer to the target.
  final List<CountImprovement> improvements;
}

/// Get the count: the 3 rounds, in order.
final class CountRun extends DuelRun {
  CountRun(List<CountRoundRun> rounds) : rounds = List.unmodifiable(rounds);

  final List<CountRoundRun> rounds;

  /// The rounds left unplayed as never improved: what quitting sends.
  CountRun completedWithEmptyRounds() => CountRun([
    ...rounds,
    for (var i = rounds.length; i < countDuelRounds; i++)
      CountRoundRun(const []),
  ]);

  @override
  Map<String, Object?> toJson() => {
    'rounds': [
      for (final round in rounds)
        {
          'improvements': [
            for (final imp in round.improvements)
              {
                'ms': imp.atMs,
                'value': imp.value,
                'steps': [for (final s in imp.steps) _stepToJson(s)],
              },
          ],
        },
    ],
  };
}

List<Object?> _stepToJson(CountStep s) => [
  s.left,
  s.operator.name,
  s.right,
  s.result,
];

CountStep _stepFromJson(Object? json) {
  if (json is! List || json.length != 4) {
    throw const FormatException('step: not [left, op, right, result]');
  }
  final [left, op, right, result] = json;
  if (left is! int || right is! int || result is! int) {
    throw const FormatException('step: not integers');
  }
  final operator = CountOperator.values.where((o) => o.name == op).firstOrNull;
  if (operator == null) throw FormatException('step: unknown operator $op');
  return CountStep(left, operator, right, result);
}

/// What an opponent sees of a run (the second lane): per question its time
/// and whether it was right; per round each improvement's time and distance
/// — never the values typed. Built by the server from a validated run, or
/// simulated for a practice opponent (`practiceLane`).
sealed class DuelLane {
  const DuelLane();

  Map<String, Object?> toJson();

  /// The score the lane stands for.
  DuelScore get score;

  static DuelLane fromJson(Object? json, DuelMode mode) {
    final root = _map(json, 'lane');
    if (mode.isQuiz) {
      return QuizLane([
        for (final (i, raw) in _list(root, 'answers').indexed)
          () {
            final a = _map(raw, 'answers[$i]');
            final correct = a['correct'];
            if (correct is! bool) {
              throw const FormatException('lane: correct is not a boolean');
            }
            return (elapsedMs: _int(a, 'ms'), correct: correct);
          }(),
      ]);
    }
    return CountLane([
      for (final (i, raw) in _list(root, 'rounds').indexed)
        () {
          final r = _map(raw, 'rounds[$i]');
          return CountLaneRound(
            baseDistance: _int(r, 'base'),
            improvements: [
              for (final (j, imp) in _list(r, 'improvements').indexed)
                () {
                  final m = _map(imp, 'improvements[$j]');
                  return (atMs: _int(m, 'ms'), distance: _int(m, 'distance'));
                }(),
            ],
          );
        }(),
    ]);
  }
}

typedef LaneAnswer = ({int elapsedMs, bool correct});

final class QuizLane extends DuelLane {
  QuizLane(List<LaneAnswer> answers) : answers = List.unmodifiable(answers);

  final List<LaneAnswer> answers;

  @override
  DuelScore get score => DuelScore(
    mode: DuelMode.basics,
    points: answers.where((a) => a.correct).length,
    totalMs: answers.fold(0, (sum, a) => sum + a.elapsedMs),
  );

  @override
  Map<String, Object?> toJson() => {
    'answers': [
      for (final a in answers) {'ms': a.elapsedMs, 'correct': a.correct},
    ],
  };
}

typedef LaneImprovement = ({int atMs, int distance});

final class CountLaneRound {
  CountLaneRound({
    required this.baseDistance,
    required List<LaneImprovement> improvements,
  }) : improvements = List.unmodifiable(improvements);

  /// The six numbers' closest distance, at 0 s.
  final int baseDistance;
  final List<LaneImprovement> improvements;

  /// The round's result: its closest distance and when it was reached.
  int get distance =>
      improvements.isEmpty ? baseDistance : improvements.last.distance;
  int get timeMs => improvements.isEmpty ? 0 : improvements.last.atMs;

  /// The closest distance reached by [ms] into the round.
  int distanceAt(int ms) {
    var best = baseDistance;
    for (final imp in improvements) {
      if (imp.atMs > ms) break;
      best = imp.distance;
    }
    return best;
  }
}

final class CountLane extends DuelLane {
  CountLane(List<CountLaneRound> rounds) : rounds = List.unmodifiable(rounds);

  final List<CountLaneRound> rounds;

  @override
  DuelScore get score => DuelScore(
    mode: DuelMode.count,
    points: rounds.fold(0, (sum, r) => sum + r.distance),
    totalMs: rounds.fold(0, (sum, r) => sum + r.timeMs),
  );

  @override
  Map<String, Object?> toJson() => {
    'rounds': [
      for (final r in rounds)
        {
          'base': r.baseDistance,
          'improvements': [
            for (final imp in r.improvements)
              {'ms': imp.atMs, 'distance': imp.distance},
          ],
        },
    ],
  };
}

/// A run's result (plan v3.7): [points] are correct answers (question
/// modes, higher is better) or the total distance (Get the count, lower is
/// better); [totalMs] breaks a tie, lower is better.
final class DuelScore {
  const DuelScore({
    required this.mode,
    required this.points,
    required this.totalMs,
  });

  /// Only [DuelMode.isQuiz] matters: Basics and Advanced score alike.
  final DuelMode mode;
  final int points;
  final int totalMs;

  Map<String, Object?> toJson() => {'points': points, 'ms': totalMs};

  @override
  bool operator ==(Object other) =>
      other is DuelScore &&
      other.mode.isQuiz == mode.isQuiz &&
      other.points == points &&
      other.totalMs == totalMs;

  @override
  int get hashCode => Object.hash(mode.isQuiz, points, totalMs);

  @override
  String toString() => 'DuelScore($points, ${totalMs}ms)';
}

/// [mine] against [theirs], from my side: 1 a win, 0.5 a draw, 0 a loss —
/// Glicko-2's score. More correct (or less distance) wins; equal → less
/// total time; equal again → a draw.
double duelResult(DuelScore mine, DuelScore theirs) {
  if (mine.points != theirs.points) {
    final better = mine.mode.isQuiz
        ? mine.points > theirs.points
        : mine.points < theirs.points;
    return better ? 1 : 0;
  }
  if (mine.totalMs != theirs.totalMs) {
    return mine.totalMs < theirs.totalMs ? 1 : 0;
  }
  return 0.5;
}

Map<String, Object?> _map(Object? v, String what) {
  if (v is! Map) throw FormatException('$what is not an object');
  return v.cast<String, Object?>();
}

List<Object?> _list(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! List) throw FormatException('$key is not a list');
  return v;
}

int _int(Map<String, Object?> m, String key) {
  final v = m[key];
  if (v is! int) throw FormatException('$key is not an integer');
  return v;
}
