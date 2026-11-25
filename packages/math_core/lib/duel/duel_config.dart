import 'dart:math';

import '../challenges/count.dart';
import '../generation/game_generator.dart';
import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../tiers/tier.dart';
import 'duel_mode.dart';

/// A duel's content (plan v3.7, Phase 7): both players get exactly the same
/// questions — or Get the count rounds — so their runs compare, and the
/// server regenerates them to replay a run. Stored with every duel and run.
///
/// [difficulty] comes from a rating, never from a player's levels:
/// - Basics, Advanced: a **tier** (0–9, [duelTierFor]); the 8 questions are
///   drawn exactly as a game at that tier draws them, under [rulesVersion]
///   (standard and pattern questions sized by tier; never weak spots);
/// - Get the count: a **band** (0–2, [countBandFor]) of the targets'
///   shortest-solution length ([countBandOperations]).
///
/// Same config → same content, on the VM and in JavaScript (rule 2; pinned
/// in `duel_config_test.dart`). Throws for retired rules or an out-of-range
/// difficulty (rule 13).
final class DuelConfig {
  DuelConfig({
    required this.mode,
    required this.seed,
    required this.difficulty,
    this.rulesVersion = RulesVersion.current,
    this.duelRules = DuelRulesVersion.current,
  }) {
    if (rulesVersion.retired) {
      throw ArgumentError.value(rulesVersion, 'rulesVersion', 'is retired.');
    }
    final top = mode.isQuiz ? Tier.values.length - 1 : countBands - 1;
    if (difficulty < 0 || difficulty > top) {
      throw ArgumentError.value(
        difficulty,
        'difficulty',
        'must be between 0 and $top for ${mode.name}.',
      );
    }
  }

  /// The config of a new duel in [mode] at [rating] (rounded to the point).
  factory DuelConfig.forRating({
    required DuelMode mode,
    required int seed,
    required int rating,
  }) => DuelConfig(
    mode: mode,
    seed: seed,
    difficulty: mode.isQuiz ? duelTierFor(rating).index : countBandFor(rating),
  );

  final DuelMode mode;
  final int seed;

  /// A tier index (Basics, Advanced) or a count band (Get the count).
  final int difficulty;

  /// The game rules a question mode draws under. Kept for every mode: one
  /// shape, and Get the count's rounds may follow them one day.
  final RulesVersion rulesVersion;

  /// The duel's own rules: content and winner (`DuelRulesVersion`).
  final DuelRulesVersion duelRules;

  /// The tier of a question mode; throws for Get the count.
  Tier get tier {
    if (!mode.isQuiz) throw StateError('Get the count has no tier.');
    return Tier.values[difficulty];
  }

  /// How many questions (question modes) or rounds (Get the count).
  int get length => mode.isQuiz ? duelQuestionCount : countDuelRounds;

  /// The type of every question, in order: two of each of the mode's
  /// types, listed by `.index` (never a `Set`'s order), shuffled with the
  /// duel's own stream — the stream that draws the values next.
  List<ExerciseType> typeSequence() => _typeSequence(Random(seed));

  List<ExerciseType> _typeSequence(Random random) {
    final types = [
      for (final type in mode.types)
        for (var i = 0; i < duelQuestionsPerType; i++) type,
    ];
    // Fisher–Yates, nextInt only (rule 18).
    for (var i = types.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final t = types[i];
      types[i] = types[j];
      types[j] = t;
    }
    return types;
  }

  /// A question mode's 8 questions, in order: one `Random(seed)`, the
  /// shuffle first, then every value through the game's own generator at
  /// the tier's lowest level. Throws for Get the count.
  List<Exercise> questions() {
    if (!mode.isQuiz) throw StateError('Get the count has rounds.');
    final random = Random(seed);
    final sequence = _typeSequence(random);
    final level = Level.whole(10 * difficulty);
    final played = {...sequence};
    final generator = gameExerciseGenerator(
      rulesVersion: rulesVersion,
      enabledTypes: played,
      levels: {for (final type in played) type: level},
      typeSequence: sequence,
    );
    return [for (var i = 0; i < sequence.length; i++) generator.next(random)];
  }

  /// Get the count's 3 rounds with their shortest solutions, from one
  /// `Random(seed)`. Throws for a question mode.
  List<(CountPuzzle, List<CountStep>)> rounds() {
    if (mode.isQuiz) throw StateError('${mode.name} has questions.');
    final random = Random(seed);
    final (minOps, maxOps) = countBandOperations(difficulty);
    return [
      for (var i = 0; i < countDuelRounds; i++)
        drawCountPuzzleInBand(random, minOps: minOps, maxOps: maxOps),
    ];
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'seed': seed,
    'difficulty': difficulty,
    'rules': rulesVersion.number,
    'duelRules': duelRules.number,
  };

  /// Strict: anything missing, mistyped or out of range throws
  /// [FormatException] — a stored duel is never guessed.
  factory DuelConfig.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('duel config: not an object');
    final seed = json['seed'];
    final difficulty = json['difficulty'];
    final rules = json['rules'];
    if (seed is! int || difficulty is! int || rules is! int) {
      throw const FormatException('duel config: seed, difficulty or rules');
    }
    try {
      return DuelConfig(
        mode: DuelMode.parse(json['mode']),
        seed: seed,
        difficulty: difficulty,
        rulesVersion: RulesVersion.of(rules),
        duelRules: DuelRulesVersion.of(json['duelRules']),
      );
    } on ArgumentError catch (e) {
      throw FormatException('duel config: ${e.message}');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DuelConfig &&
      other.mode == mode &&
      other.seed == seed &&
      other.difficulty == difficulty &&
      other.rulesVersion == rulesVersion &&
      other.duelRules == duelRules;

  @override
  int get hashCode =>
      Object.hash(mode, seed, difficulty, rulesVersion, duelRules);

  @override
  String toString() => 'DuelConfig(${toJson()})';
}

/// Basics and Advanced: two questions of each of four types.
const duelQuestionsPerType = 2;
const duelQuestionCount = 8;

/// Get the count in a duel: 3 rounds of 30 s (solo keeps 45 s).
const countDuelRounds = 3;
const countDuelRoundSeconds = 30;
const countDuelRoundMs = countDuelRoundSeconds * 1000;

/// Every 150 rating points is one tier (plan v3.7): 900 → T0, 1500 → T4,
/// 2250 and above → T9; below 900 stays T0.
Tier duelTierFor(int rating) {
  if (rating < 900) return Tier.values.first;
  final index = (rating - 900) ~/ 150;
  return index >= Tier.values.length ? Tier.values.last : Tier.values[index];
}

/// Get the count's three bands (plan v3.7; thresholds tunable): below 1300,
/// 1300–1700, above 1700.
const countBands = 3;

int countBandFor(int rating) => rating < 1300
    ? 0
    : rating <= 1700
    ? 1
    : 2;

/// A band's shortest-solution lengths, in operations: 2–3, 3–4, 4–5.
(int, int) countBandOperations(int band) => switch (band) {
  0 => (2, 3),
  1 => (3, 4),
  2 => (4, 5),
  _ => throw ArgumentError.value(band, 'band', 'must be 0, 1 or 2.'),
};
