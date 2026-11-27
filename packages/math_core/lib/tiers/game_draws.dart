import 'dart:math';

import '../models/exercise.dart';
import '../models/exercise_type.dart';
import '../patterns/pattern_family.dart';
import '../patterns/pattern_questions.dart';
import '../patterns/pattern_spaces_v9.dart';
import '../weak_spots/facts.dart';
import '../weak_spots/item.dart';
import 'draw.dart';
import 'question_space.dart';
import 'standard_v9.dart';
import 'tier.dart';
import 'tier_content.dart';

/// How a game generator draws its questions (`TieredGameGenerator`): a
/// question of an operation at a tier, a weak-spot fact, a weak-spot
/// skill. Stateless under rules v2–v8 ([ContentDraws]); from rules v9 a
/// game's own memory ([DrawsV9]): no repeat, never two in a row.
abstract interface class GameDraws {
  /// A question of [type] at [tier], with its pattern family if it is one.
  TierQuestion question(ExerciseType type, Tier tier, Random random);

  /// [fact], re-asked at [tier] (a weak spot that belongs to it).
  Exercise fact(FactItem fact, Tier tier, Random random);

  /// A question of [family] at [tier] (a weak-spot skill).
  Exercise skill(PatternFamily family, Tier tier, Random random);
}

/// Rules v2–v8: each question on its own, from its rules' [content] — the
/// draws exactly as they were (their pinned references hold them).
final class ContentDraws implements GameDraws {
  const ContentDraws(this.content);

  final TierContent content;

  @override
  TierQuestion question(ExerciseType type, Tier tier, Random random) =>
      content(type, tier, random);

  @override
  Exercise fact(FactItem fact, Tier tier, Random random) =>
      drawOne(random, formsAt(fact, tier));

  @override
  Exercise skill(PatternFamily family, Tier tier, Random random) =>
      patternQuestion(family, tier, random);
}

/// Rules v9 (`doc/levels.md` v1.6): one game's draws. Standard questions
/// from `standardSpaceV9`, pattern questions 2 in 5 where a family is
/// available (`familiesAtV9`: skipped below 4 distinct questions), each
/// from `familySpaceV9` — every source of an operation through one
/// [OperationDraws], so a question is never asked twice while its space
/// has others, never twice in a row, and never again from another source.
/// The weak spots' facts are kept out of the other draws ([reserve]); they
/// are asked as such.
final class DrawsV9 implements GameDraws {
  DrawsV9({List<Item> weakSpots = const []}) {
    for (final item in weakSpots) {
      if (item case final FactItem fact) {
        _of(fact.type).reserve([factKey(fact)]);
      }
    }
  }

  final _byType = <ExerciseType, OperationDraws>{};

  OperationDraws _of(ExerciseType type) =>
      _byType.putIfAbsent(type, OperationDraws.new);

  /// A pattern question 2 times in 5 where a family is available, its
  /// family uniformly among them; else a standard question. **The tier
  /// counts, not the source** ("no question twice in a game while the tier
  /// still has unused questions"): when the chosen source has nothing left
  /// unasked, a family with something left is drawn instead, else the
  /// standard questions; only when the whole tier is used up does a source
  /// repeat — never twice in a row.
  @override
  TierQuestion question(ExerciseType type, Tier tier, Random random) {
    final draws = _of(type);
    final families = familiesAtV9(type, tier);
    final standard = standardSpaceV9(type, tier);
    final wantsPattern =
        families.isNotEmpty && random.nextInt(5) < patternShareFifths;
    PatternFamily? family = wantsPattern ? drawOne(random, families) : null;
    final chosen = family == null ? standard : familySpaceV9(family, tier);
    if (draws.fresh(chosen) == 0) {
      final left = [
        for (final f in families)
          if (draws.fresh(familySpaceV9(f, tier)) > 0) f,
      ];
      if (left.isNotEmpty) {
        // Another family first: the pattern share stays near 2 in 5.
        family = drawOne(random, left);
      } else if (family != null && draws.fresh(standard) > 0) {
        family = null;
      }
    }
    return (
      exercise: draws.draw(
        family == null ? standard : familySpaceV9(family, tier),
        random,
      ),
      family: family,
    );
  }

  @override
  Exercise fact(FactItem fact, Tier tier, Random random) {
    final question = standardSpaceV9(
      fact.type,
      tier,
    ).ask(factKey(fact), random);
    _of(fact.type).note(question, fact);
    return question;
  }

  @override
  Exercise skill(PatternFamily family, Tier tier, Random random) =>
      _of(family.type).draw(familySpaceV9(family, tier), random);
}

/// The question [fact] asks, as a key ([canonicalOf]).
Exercise factKey(FactItem fact) => canonicalOf(exercisesOf(fact).first);

/// Whether rules v9's [tier] asks [fact] among its standard questions.
bool factAtV9(FactItem fact, Tier tier) =>
    standardSpaceV9(fact.type, tier).containsKey(factKey(fact));
