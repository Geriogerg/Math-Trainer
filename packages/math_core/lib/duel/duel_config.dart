import 'dart:math';

import '../generation/game_generator.dart';
import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';

/// A duel's questions (Phase 5.2 commit 2, Phase 7's first commit moved
/// earlier): both players get the same ones, so they can be compared — and
/// the server can regenerate them to check a run (Phase 7 commit 2).
///
/// Nothing comes from either player's levels: the difficulty is the
/// [bracket]'s, from the players' rating (Glicko-2, server side), and the
/// mix is a fixed quota per type. Same (seed, config) → same questions, on
/// the VM and in JavaScript (rule 2; pinned in `duel_config_test.dart`).
/// No UI yet.
final class DuelConfig {
  DuelConfig({
    required this.seed,
    required Map<ExerciseType, int> quotas,
    required this.bracket,
  }) : quotas = Map.unmodifiable(quotas) {
    if (bracket < 0 || bracket >= duelBracketCount) {
      throw ArgumentError.value(
        bracket,
        'bracket',
        'must be between 0 and ${duelBracketCount - 1}.',
      );
    }
    for (final MapEntry(key: type, value: count) in quotas.entries) {
      if (count < 0) {
        throw ArgumentError.value(
          count,
          'quotas[${type.name}]',
          'is negative.',
        );
      }
    }
    final total = quotas.values.fold(0, (a, b) => a + b);
    if (total < 1 || total > maxDuelQuestions) {
      throw ArgumentError.value(
        total,
        'quotas',
        'must add up to between 1 and $maxDuelQuestions questions.',
      );
    }
  }

  final int seed;

  /// How many questions of each type; a type absent or at 0 is not played.
  final Map<ExerciseType, int> quotas;

  /// The rating bracket the duel is played at ([duelBracketFor]).
  final int bracket;

  int get questionCount => quotas.values.fold(0, (a, b) => a + b);

  /// The level every type is generated at: the bracket's, never a player's.
  Level get level => duelBracketLevel(bracket);

  /// The type of every question, in order: the quotas, listed by type
  /// (`ExerciseType.index`, never a `Set`'s order), then shuffled with the
  /// duel's own random stream — the same stream that draws the values next.
  List<ExerciseType> typeSequence() => _typeSequence(Random(seed));

  List<ExerciseType> _typeSequence(Random random) {
    final types = [
      for (final type in ExerciseType.values)
        for (var i = 0; i < (quotas[type] ?? 0); i++) type,
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

  /// The duel's questions, in order. One `Random(seed)`: the shuffle first,
  /// then every value, as a game's generator draws them.
  List<Exercise> questions() {
    final random = Random(seed);
    final sequence = _typeSequence(random);
    final played = {
      for (final type in ExerciseType.values)
        if ((quotas[type] ?? 0) > 0) type,
    };
    // Like a game under the current rules: the bracket's tier, with its
    // reviews (Levels phase commit 4 — no duel was stored before).
    final generator = gameExerciseGenerator(
      rulesVersion: RulesVersion.current,
      enabledTypes: played,
      levels: {for (final type in played) type: level},
      typeSequence: sequence,
    );
    return [for (var i = 0; i < sequence.length; i++) generator.next(random)];
  }

  Map<String, Object?> toJson() => {
    'seed': seed,
    'bracket': bracket,
    // By type index: the same JSON for the same quotas, whatever the
    // map's order.
    'quotas': {
      for (final type in ExerciseType.values)
        if ((quotas[type] ?? 0) > 0) type.name: quotas[type],
    },
  };

  /// Strict: anything missing, mistyped or out of range throws
  /// [FormatException] (a stored duel is never guessed).
  factory DuelConfig.fromJson(Object? json) {
    if (json is! Map) throw const FormatException('duel config: not an object');
    final seed = json['seed'];
    final bracket = json['bracket'];
    final quotas = json['quotas'];
    if (seed is! int || bracket is! int || quotas is! Map) {
      throw const FormatException('duel config: seed, bracket or quotas');
    }
    final parsed = <ExerciseType, int>{};
    for (final MapEntry(:key, :value) in quotas.entries) {
      final type = ExerciseType.values.where((t) => t.name == key).firstOrNull;
      if (type == null || value is! int) {
        throw FormatException('duel config: quota $key');
      }
      parsed[type] = value;
    }
    try {
      return DuelConfig(seed: seed, quotas: parsed, bracket: bracket);
    } on ArgumentError catch (e) {
      throw FormatException('duel config: ${e.message}');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! DuelConfig ||
        other.seed != seed ||
        other.bracket != bracket) {
      return false;
    }
    for (final type in ExerciseType.values) {
      if ((other.quotas[type] ?? 0) != (quotas[type] ?? 0)) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    seed,
    bracket,
    Object.hashAll([for (final type in ExerciseType.values) quotas[type] ?? 0]),
  );
}

/// The longest duel accepted.
const maxDuelQuestions = 40;

/// A duel of twelve: every type, the four operations twice, percentages
/// twice (provisional, Phase 5.2; Phase 7 tunes it on play).
const standardDuelQuotas = {
  ExerciseType.addition: 2,
  ExerciseType.subtraction: 2,
  ExerciseType.multiplication: 2,
  ExerciseType.division: 2,
  ExerciseType.power: 1,
  ExerciseType.squareRoot: 1,
  ExerciseType.percentage: 2,
};

/// Fifteen brackets of 100 rating points: up to 899, 900–999, …, 2200 and
/// above (Glicko-2's scale: a new player starts at 1500, bracket 7).
const duelBracketCount = 15;
const _lowestBracketTop = 900;
const _bracketWidth = 100;

/// The bracket of a rating, rounded to the point (the server rounds).
/// Two players of different ratings duel at the bracket of their mean
/// (the server's choice, Phase 7).
int duelBracketFor(int rating) {
  if (rating < _lowestBracketTop) return 0;
  final bracket = (rating - _lowestBracketTop) ~/ _bracketWidth + 1;
  return bracket >= duelBracketCount ? duelBracketCount - 1 : bracket;
}

/// The level of a bracket: 5, 10, …, 75 — bracket 7 (rating 1500, a new
/// player) at 40. Provisional (Phase 5.2): Phase 7 calibrates it on the
/// levels players actually reach.
Level duelBracketLevel(int bracket) {
  if (bracket < 0 || bracket >= duelBracketCount) {
    throw ArgumentError.value(
      bracket,
      'bracket',
      'must be between 0 and ${duelBracketCount - 1}.',
    );
  }
  return Level.whole(5 + 5 * bracket);
}
