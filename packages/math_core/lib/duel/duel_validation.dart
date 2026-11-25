import '../challenges/count.dart';
import '../models/answer_result.dart';
import '../validation/session_validation.dart';
import 'duel_config.dart';
import 'duel_run.dart';

/// Why a duel run was refused (Phase 7 commit 2). The names are stored
/// server-side (`duel_run_rejections.reason`) and sent to the app: renaming
/// one breaks both.
enum DuelRunProblem {
  /// Answers for Get the count or rounds for a question mode, or not the
  /// duel's number of questions or rounds.
  wrongShape,

  /// A response time outside [0, 30 s], or an improvement outside its
  /// round.
  badElapsed,

  /// An improvement's operations do not make its value from the round's
  /// six numbers (a number used twice, a forbidden or wrong result).
  badDerivation,

  /// An improvement no closer to the target than what came before.
  notCloser,

  /// An improvement not later than the one before.
  notLater,

  /// An improvement after the target was reached (the round had ended).
  afterTarget,
}

sealed class DuelRunVerdict {
  const DuelRunVerdict();
}

/// A run that replays: its score, the lane an opponent will see, and the
/// fair-play flags that keep it out of the pool until reviewed.
final class DuelRunValid extends DuelRunVerdict {
  const DuelRunValid({
    required this.score,
    required this.lane,
    required this.flags,
  });

  final DuelScore score;
  final DuelLane lane;
  final Set<ValidationFlag> flags;
}

final class DuelRunInvalid extends DuelRunVerdict {
  const DuelRunInvalid(this.problem, this.detail);

  final DuelRunProblem problem;

  /// For the logs; never shown to players.
  final String detail;
}

/// Most improvements a round may hold: far more than 30 s allows.
const maxImprovementsPerRound = 60;

/// Most operations an improvement may take: six numbers make five at most.
const _maxSteps = 5;

/// The server's replay of a duel run (plan v3.7: "every duel run is
/// replayed and validated by the server like any game"): the content
/// regenerated from [config], every answer rechecked, every Get the count
/// improvement re-derived from its round's numbers. Pure, VM and
/// JavaScript; the app calls it too, to show its own result at once.
DuelRunVerdict validateDuelRun(DuelConfig config, DuelRun run) => switch (run) {
  QuizRun() => _quiz(config, run),
  CountRun() => _count(config, run),
};

DuelRunVerdict _quiz(DuelConfig config, QuizRun run) {
  if (!config.mode.isQuiz || run.answers.length != duelQuestionCount) {
    return DuelRunInvalid(
      DuelRunProblem.wrongShape,
      '${run.answers.length} answers for ${config.mode.name}',
    );
  }
  final questions = config.questions();
  final outcomes = <AnswerResult>[];
  final lane = <LaneAnswer>[];
  for (final (i, answer) in run.answers.indexed) {
    if (answer.elapsedMs < 0 || answer.elapsedMs > maxElapsedMs) {
      return DuelRunInvalid(
        DuelRunProblem.badElapsed,
        'answer $i: ${answer.elapsedMs}',
      );
    }
    final question = questions[i];
    final correct =
        answer.value != timeoutSubmittedValue &&
        question.isCorrectAnswer(answer.value);
    outcomes.add(
      AnswerResult(
        exercise: question,
        submittedValue: answer.value,
        isCorrect: correct,
        elapsedMs: answer.elapsedMs,
        answeredAt: DateTime.utc(2026),
      ),
    );
    lane.add((elapsedMs: answer.elapsedMs, correct: correct));
  }
  final quizLane = QuizLane(lane);
  return DuelRunValid(
    score: DuelScore(
      mode: config.mode,
      points: quizLane.score.points,
      totalMs: quizLane.score.totalMs,
    ),
    lane: quizLane,
    // The solo game's timing rules (plan 6.4), flagged, never refused.
    flags: timingFlags(outcomes),
  );
}

DuelRunVerdict _count(DuelConfig config, CountRun run) {
  if (config.mode.isQuiz || run.rounds.length != countDuelRounds) {
    return DuelRunInvalid(
      DuelRunProblem.wrongShape,
      '${run.rounds.length} rounds for ${config.mode.name}',
    );
  }
  final rounds = config.rounds();
  final lane = <CountLaneRound>[];
  var fastSolves = 0;
  for (final (r, round) in run.rounds.indexed) {
    final (puzzle, solution) = rounds[r];
    if (round.improvements.length > maxImprovementsPerRound) {
      return DuelRunInvalid(
        DuelRunProblem.wrongShape,
        'round $r: ${round.improvements.length} improvements',
      );
    }
    final base = baseCountDistance(puzzle);
    var best = base;
    var lastMs = -1;
    final improvements = <LaneImprovement>[];
    for (final (i, imp) in round.improvements.indexed) {
      final where = 'round $r, improvement $i';
      if (imp.atMs < 0 || imp.atMs > countDuelRoundMs) {
        return DuelRunInvalid(DuelRunProblem.badElapsed, '$where: ${imp.atMs}');
      }
      if (imp.atMs <= lastMs) {
        return DuelRunInvalid(DuelRunProblem.notLater, where);
      }
      if (best == 0) return DuelRunInvalid(DuelRunProblem.afterTarget, where);
      if (!derives(puzzle.numbers, imp.steps, imp.value)) {
        return DuelRunInvalid(DuelRunProblem.badDerivation, where);
      }
      final distance = (imp.value - puzzle.target).abs();
      if (distance >= best) {
        return DuelRunInvalid(DuelRunProblem.notCloser, where);
      }
      best = distance;
      lastMs = imp.atMs;
      improvements.add((atMs: imp.atMs, distance: distance));
    }
    // A target of 3 operations or more reached in under 3 s: no one
    // computes that fast — twice in a duel is flagged.
    if (best == 0 && lastMs < 3000 && solution.length >= 3) fastSolves++;
    lane.add(CountLaneRound(baseDistance: base, improvements: improvements));
  }
  final countLane = CountLane(lane);
  return DuelRunValid(
    score: countLane.score,
    lane: countLane,
    flags: {if (fastSolves >= 2) ValidationFlag.implausiblyFast},
  );
}

/// The six numbers' closest distance to the target: what a round is worth
/// before any move (`CountBoard.closest` at the start).
int baseCountDistance(CountPuzzle puzzle) {
  var best = (puzzle.numbers.first - puzzle.target).abs();
  for (final n in puzzle.numbers) {
    final d = (n - puzzle.target).abs();
    if (d < best) best = d;
  }
  return best;
}

/// Whether [steps] make [value] from [numbers], each number (and each
/// intermediate result) used at most once, every operation allowed by the
/// rules (`CountOperator.apply`). No steps: [value] must be one of the
/// numbers.
bool derives(List<int> numbers, List<CountStep> steps, int value) {
  if (steps.length > _maxSteps) return false;
  if (steps.isEmpty) return numbers.contains(value);
  final available = [...numbers];
  for (final step in steps) {
    if (!available.remove(step.left) || !available.remove(step.right)) {
      return false;
    }
    if (step.operator.apply(step.left, step.right) != step.result) return false;
    available.add(step.result);
  }
  return steps.last.result == value;
}
