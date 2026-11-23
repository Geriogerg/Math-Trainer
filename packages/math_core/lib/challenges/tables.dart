import 'dart:math';

import '../models/answer_result.dart';
import '../models/exercise.dart';
import '../models/operation_type.dart';

/// Tables mode (`doc/levels.md`, section 7): multiplication tables from 1
/// to 50, practised on the game screen. Practice only — never a level,
/// never ranked, never uploaded; its stats stay on the device.

/// The tables the setup offers.
const tablesMin = 1;
const tablesMax = 50;

/// Multipliers 1–10 or 1–20.
const tablesMultiplierChoices = [10, 20];

/// Questions per round.
const tablesQuestionChoices = [10, 20, 50];

/// The setup page's choices; remembered between launches. Throws on a
/// choice the page does not offer (rule 13).
final class TablesSetup {
  TablesSetup({
    this.firstTable = 2,
    this.lastTable = 10,
    this.maxMultiplier = 10,
    this.questions = 20,
  }) {
    if (firstTable < tablesMin ||
        lastTable > tablesMax ||
        firstTable > lastTable) {
      throw ArgumentError.value(
        (firstTable, lastTable),
        'tables',
        'must satisfy $tablesMin <= first <= last <= $tablesMax.',
      );
    }
    if (!tablesMultiplierChoices.contains(maxMultiplier)) {
      throw ArgumentError.value(
        maxMultiplier,
        'maxMultiplier',
        'must be one of $tablesMultiplierChoices.',
      );
    }
    if (!tablesQuestionChoices.contains(questions)) {
      throw ArgumentError.value(
        questions,
        'questions',
        'must be one of $tablesQuestionChoices.',
      );
    }
  }

  final int firstTable;
  final int lastTable;
  final int maxMultiplier;
  final int questions;

  TablesSetup copyWith({
    int? firstTable,
    int? lastTable,
    int? maxMultiplier,
    int? questions,
  }) => TablesSetup(
    firstTable: firstTable ?? this.firstTable,
    lastTable: lastTable ?? this.lastTable,
    maxMultiplier: maxMultiplier ?? this.maxMultiplier,
    questions: questions ?? this.questions,
  );

  @override
  bool operator ==(Object other) =>
      other is TablesSetup &&
      other.firstTable == firstTable &&
      other.lastTable == lastTable &&
      other.maxMultiplier == maxMultiplier &&
      other.questions == questions;

  @override
  int get hashCode =>
      Object.hash(firstTable, lastTable, maxMultiplier, questions);
}

/// A round's questions: every fact of the chosen tables (table ×
/// multiplier, the table first, as "17 × 6"), shuffled by [seed]; a round
/// longer than the facts deals them again, each pass shuffled anew, so a
/// fact never comes back before every other one has been asked. Seeded and
/// pure (rule 2), so a later phase can replay it.
List<ArithmeticExercise> tablesQuestions({
  required int seed,
  required TablesSetup setup,
}) {
  final facts = [
    for (var t = setup.firstTable; t <= setup.lastTable; t++)
      for (var m = 1; m <= setup.maxMultiplier; m++) (t, m),
  ];
  final random = Random(seed);
  final questions = <ArithmeticExercise>[];
  while (questions.length < setup.questions) {
    final pass = [...facts];
    for (var i = pass.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final swap = pass[i];
      pass[i] = pass[j];
      pass[j] = swap;
    }
    for (final (t, m) in pass) {
      if (questions.length == setup.questions) break;
      questions.add(
        ArithmeticExercise(
          operandA: t,
          operandB: m,
          operationType: OperationType.multiplication,
        ),
      );
    }
  }
  return questions;
}

/// One fact's record: how often asked, answered right, and its total time.
final class FactRecord {
  const FactRecord({this.asked = 0, this.right = 0, this.totalMs = 0});

  final int asked;
  final int right;
  final int totalMs;

  double get averageMs => asked == 0 ? 0 : totalMs / asked;

  @override
  bool operator ==(Object other) =>
      other is FactRecord &&
      other.asked == asked &&
      other.right == right &&
      other.totalMs == totalMs;

  @override
  int get hashCode => Object.hash(asked, right, totalMs);
}

/// Tables mode's personal stats, on the device only: rounds played, answers
/// and right answers (a raw count, never a rate presented as progress —
/// `doc/decisions.md`), and every fact's record, from which the slowest.
final class TablesStats {
  const TablesStats({
    this.games = 0,
    this.answers = 0,
    this.right = 0,
    this.facts = const {},
  });

  static const none = TablesStats();

  final int games;
  final int answers;
  final int right;

  /// By fact key, "17x6" ([factKey]).
  final Map<String, FactRecord> facts;

  static String factKey(int table, int multiplier) => '${table}x$multiplier';

  /// One finished round's [outcomes] added in.
  TablesStats record(List<AnswerResult> outcomes) {
    final updated = Map<String, FactRecord>.of(facts);
    var right = 0;
    for (final outcome in outcomes) {
      final exercise = outcome.exercise;
      if (exercise is! ArithmeticExercise ||
          exercise.operationType != OperationType.multiplication) {
        throw ArgumentError.value(outcome, 'outcomes', 'not a table fact.');
      }
      final key = factKey(exercise.operandA, exercise.operandB);
      final before = updated[key] ?? const FactRecord();
      updated[key] = FactRecord(
        asked: before.asked + 1,
        right: before.right + (outcome.isCorrect ? 1 : 0),
        totalMs: before.totalMs + outcome.elapsedMs,
      );
      if (outcome.isCorrect) right++;
    }
    return TablesStats(
      games: games + 1,
      answers: answers + outcomes.length,
      right: this.right + right,
      facts: updated,
    );
  }

  /// The [count] facts with the longest average time, slowest first (ties:
  /// the smaller table, then multiplier, first).
  List<({int table, int multiplier, double averageMs})> slowest(int count) {
    final all = [
      for (final MapEntry(:key, :value) in facts.entries)
        () {
          final [t, m] = key.split('x').map(int.parse).toList();
          return (table: t, multiplier: m, averageMs: value.averageMs);
        }(),
    ];
    all.sort((a, b) {
      final byTime = b.averageMs.compareTo(a.averageMs);
      if (byTime != 0) return byTime;
      final byTable = a.table.compareTo(b.table);
      return byTable != 0 ? byTable : a.multiplier.compareTo(b.multiplier);
    });
    return all.take(count).toList();
  }

  Map<String, Object?> toJson() => {
    'games': games,
    'answers': answers,
    'right': right,
    'facts': {
      for (final MapEntry(:key, :value) in facts.entries)
        key: [value.asked, value.right, value.totalMs],
    },
  };

  /// Throws [FormatException] on anything else than [toJson]'s shape.
  factory TablesStats.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('not an object');
    int whole(Object? v) =>
        v is int && v >= 0 ? v : throw FormatException('not a count: $v');
    final facts = json['facts'];
    if (facts is! Map) throw const FormatException('facts');
    return TablesStats(
      games: whole(json['games']),
      answers: whole(json['answers']),
      right: whole(json['right']),
      facts: {
        for (final MapEntry(:key, :value) in facts.entries)
          if (value is List && value.length == 3)
            '$key': FactRecord(
              asked: whole(value[0]),
              right: whole(value[1]),
              totalMs: whole(value[2]),
            )
          else
            '$key': throw FormatException('fact $key'),
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TablesStats &&
      other.games == games &&
      other.answers == answers &&
      other.right == right &&
      other.facts.length == facts.length &&
      facts.entries.every((e) => other.facts[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    games,
    answers,
    right,
    Object.hashAllUnordered(
      facts.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Tables mode's setup and stats, on the device (rule 3: the concrete store
/// lives in the app's `infrastructure/`).
abstract class TablesStore {
  /// `null`: never stored, or a choice this build does not offer.
  Future<TablesSetup?> loadSetup();

  Future<void> saveSetup(TablesSetup setup);

  Future<TablesStats> loadStats();

  Future<void> saveStats(TablesStats stats);
}
