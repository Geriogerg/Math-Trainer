import 'dart:math';

import '../generation/exercise_generator.dart';
import '../leveling/level.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../weak_spots/item.dart';
import 'game_draws.dart';
import 'tier.dart';
import 'tier_content.dart';

/// A game's questions under rules v2 and later (`doc/levels.md`, sections
/// 2, 5 and 5b), each drawn by its rules' [TierContent] at the tier of its
/// operation's frozen level.
///
/// [withReviews] (rules v2–v4, spec v1.2): **30 % of an operation's
/// questions from the tier below** (review; none at T0). Rules v5 (spec
/// v1.4) has none — every question from the player's tier — and draws
/// nothing for it.
///
/// The review count is exact per operation ([reviewQuestionCount]: 1 of 4,
/// 2 of 5, 3 of 10, 6 of 20); which questions are reviews is drawn on the
/// game's stream as it goes — the k-th of m remaining questions is a review
/// with probability (reviews left) / m, so every arrangement is equally
/// likely and the count always lands exactly. Needs the stored type
/// sequence: replay never guesses (rule 2).
///
/// [weakSpots] (rules v7, Phase 4): items re-asked in place of some of
/// their operation's questions, placed the same way as reviews — the k-th
/// of m remaining questions of an operation is a weak spot with probability
/// (its items left) / m, each operation's items in their stored order. A
/// fact is asked in one of the forms its tier draws ([formsAt]), a skill as
/// a new question of its family at the tier's size ([patternQuestion]).
/// Nothing is drawn for them when there are none. The caller checks the
/// items belong to the tier (`weakSpotProblem`); never with reviews.
///
/// Each question is drawn by [draws]: [content], one question on its own,
/// under rules v2–v8 ([ContentDraws]); from rules v9 the game's own memory
/// ([DrawsV9]: no repeat, never two in a row) — the placement of reviews
/// and weak spots on the stream is the same.
class TieredGameGenerator implements ExerciseGenerator {
  /// Exactly one of [content] (rules v2–v8) and [draws] (v9 on).
  TieredGameGenerator({
    required List<ExerciseType> sequence,
    required Map<ExerciseType, Level> levels,
    TierContent? content,
    GameDraws? draws,
    required this.withReviews,
    List<Item> weakSpots = const [],
  }) : draws =
           draws ??
           ContentDraws(
             content ??
                 (throw ArgumentError.value(
                   content,
                   'content',
                   'or draws is needed.',
                 )),
           ),
       _sequence = List.unmodifiable(sequence),
       _tiers = {
         for (final type in sequence.toSet())
           type: Tier.of(
             levels[type] ??
                 (throw ArgumentError.value(
                   levels,
                   'levels',
                   'has no level for ${type.name}.',
                 )),
           ),
       } {
    if (sequence.isEmpty) {
      throw ArgumentError.value(sequence, 'sequence', 'must not be empty.');
    }
    if (content != null && draws != null) {
      throw ArgumentError.value(draws, 'draws', 'not with content.');
    }
    for (final type in sequence) {
      _remaining[type] = (_remaining[type] ?? 0) + 1;
    }
    for (final MapEntry(key: type, value: count) in _remaining.entries) {
      _reviewsLeft[type] = withReviews
          ? reviewQuestionCount(_tiers[type]!, count)
          : 0;
    }
    if (weakSpots.isNotEmpty && withReviews) {
      throw ArgumentError.value(weakSpots, 'weakSpots', 'not with reviews.');
    }
    for (final item in weakSpots) {
      if (!_tiers.containsKey(item.type)) {
        throw ArgumentError.value(item, 'weakSpots', 'not a game operation.');
      }
      _spots.putIfAbsent(item.type, () => []).add(item);
    }
  }

  /// How each question is drawn: its rules' content, or v9's memory.
  final GameDraws draws;

  /// 30 % review questions from the tier below (rules v2–v4).
  final bool withReviews;
  final List<ExerciseType> _sequence;
  final Map<ExerciseType, Tier> _tiers;
  final _remaining = <ExerciseType, int>{};
  final _reviewsLeft = <ExerciseType, int>{};
  final _spots = <ExerciseType, List<Item>>{};
  final _spotsUsed = <ExerciseType, int>{};
  int _position = 0;

  /// The weak spot the last question re-asked; `null` for any other.
  Item? get lastWeakSpot => _lastWeakSpot;
  Item? _lastWeakSpot;

  /// The tier the last question was drawn from (its operation's, or the one
  /// below for a review). For tests and analysis; nothing is stored.
  Tier? get lastTier => _lastTier;
  Tier? _lastTier;

  /// The pattern family the last question came from; `null` for a standard
  /// question (and always under rules v2 and v3). The Method and analysis
  /// read it; nothing is stored — a replay recomputes it.
  PatternFamily? get lastFamily => _lastFamily;
  PatternFamily? _lastFamily;

  @override
  Exercise next(Random random) {
    if (_position >= _sequence.length) {
      throw StateError('Sequence exhausted ($_position/${_sequence.length}).');
    }
    final type = _sequence[_position++];
    final tier = _tiers[type]!;
    final remaining = _remaining[type]!;
    final reviews = _reviewsLeft[type]!;
    final review = reviews > 0 && random.nextInt(remaining) < reviews;
    final spots = _spots[type] ?? const <Item>[];
    final used = _spotsUsed[type] ?? 0;
    final spotsLeft = spots.length - used;
    final weak = spotsLeft > 0 && random.nextInt(remaining) < spotsLeft;
    _remaining[type] = remaining - 1;
    if (weak) {
      final item = spots[used];
      _spotsUsed[type] = used + 1;
      _lastTier = tier;
      _lastWeakSpot = item;
      switch (item) {
        case FactItem():
          _lastFamily = null;
          return draws.fact(item, tier, random);
        case SkillItem(:final family):
          _lastFamily = family;
          return draws.skill(family, tier, random);
      }
    }
    _lastWeakSpot = null;
    if (review) _reviewsLeft[type] = reviews - 1;
    final drawn = review ? tier.below! : tier;
    _lastTier = drawn;
    final question = draws.question(type, drawn, random);
    _lastFamily = question.family;
    return question.exercise;
  }
}
