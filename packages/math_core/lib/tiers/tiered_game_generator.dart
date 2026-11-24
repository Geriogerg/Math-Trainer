import 'dart:math';

import '../generation/exercise_generator.dart';
import '../leveling/level.dart';
import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
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
class TieredGameGenerator implements ExerciseGenerator {
  TieredGameGenerator({
    required List<ExerciseType> sequence,
    required Map<ExerciseType, Level> levels,
    required this.content,
    required this.withReviews,
  }) : _sequence = List.unmodifiable(sequence),
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
    for (final type in sequence) {
      _remaining[type] = (_remaining[type] ?? 0) + 1;
    }
    for (final MapEntry(key: type, value: count) in _remaining.entries) {
      _reviewsLeft[type] = withReviews
          ? reviewQuestionCount(_tiers[type]!, count)
          : 0;
    }
  }

  /// How one question is drawn: its rules' content.
  final TierContent content;

  /// 30 % review questions from the tier below (rules v2–v4).
  final bool withReviews;
  final List<ExerciseType> _sequence;
  final Map<ExerciseType, Tier> _tiers;
  final _remaining = <ExerciseType, int>{};
  final _reviewsLeft = <ExerciseType, int>{};
  int _position = 0;

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
    _remaining[type] = remaining - 1;
    if (review) _reviewsLeft[type] = reviews - 1;
    final drawn = review ? tier.below! : tier;
    _lastTier = drawn;
    final question = content(type, drawn, random);
    _lastFamily = question.family;
    return question.exercise;
  }
}
