import 'dart:math';

import '../generation/composite_exercise_generator.dart';
import '../generation/exercise_source.dart';
import '../models/answer_result.dart';
import '../models/exercise.dart';
import 'placement.dart';

typedef PlacementAnswer = ({bool isCorrect, int elapsedMs});

/// The placement test's questions: the four basic operations in turn, each
/// at its staircase's current level. Adaptive, yet deterministic (rule 2):
/// question `i` depends only on the seed and the answers before it.
class PlacementExerciseSource extends ExerciseSource {
  PlacementExerciseSource({required int seed, this.rules = placementRulesV1})
    : _random = Random(seed);

  final PlacementRules rules;
  final Random _random;
  final _answers = <PlacementAnswer>[];
  int _asked = 0;

  @override
  Exercise next() {
    if (_asked > _answers.length) {
      // The controller tells every answer before asking the next question;
      // two `next()` in a row would draw a level from stale answers.
      throw StateError(
        'next() called before the answer to question $_asked was given',
      );
    }
    return _questionAt(_asked++, _answers, _random, rules);
  }

  @override
  void onAnswered(AnswerResult outcome) => _answers.add((
    isCorrect: outcome.isCorrect,
    elapsedMs: outcome.elapsedMs,
  ));
}

/// The questions of a placement given its [seed] and [answers] in order —
/// what the server regenerates to check a stored placement. Question `i` is
/// asked before answer `i` exists, so `answers.length` questions are
/// regenerated (one more is possible only for a live session).
List<Exercise> replayPlacementQuestions({
  required int seed,
  required List<PlacementAnswer> answers,
  PlacementRules rules = placementRulesV1,
}) {
  final random = Random(seed);
  return [
    for (var i = 0; i < answers.length; i++)
      _questionAt(i, answers.sublist(0, i), random, rules),
  ];
}

Exercise _questionAt(
  int index,
  List<PlacementAnswer> answersBefore,
  Random random,
  PlacementRules rules,
) {
  final type = placementTypeAt(index);
  final level = replayStaircases(answersBefore, rules)[type]!.level;
  return exerciseGeneratorFor(type, level.whole).next(random);
}
