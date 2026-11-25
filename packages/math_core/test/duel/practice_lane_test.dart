import 'package:math_core/duel/duel_config.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/duel/practice_lane.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/tiers/fluent_time.dart';
import 'package:test/test.dart';

DuelConfig _duel(DuelMode mode, int seed, int difficulty) => DuelConfig(
  mode: mode,
  seed: seed,
  difficulty: difficulty,
  rulesVersion: RulesVersion.v8,
);

void main() {
  test('pinned: the same lane on the VM and in JavaScript', () {
    final quiz = practiceLane(_duel(DuelMode.basics, 1, 4)) as QuizLane;
    expect(quiz.toJson(), practiceLane(_duel(DuelMode.basics, 1, 4)).toJson());
    // Recorded on the VM at Phase 7 commit 4.
    expect(
      quiz.score,
      const DuelScore(
        mode: DuelMode.basics,
        points: pinnedQuizPoints,
        totalMs: pinnedQuizMs,
      ),
    );
    final count = practiceLane(_duel(DuelMode.count, 987654321, 2));
    expect(count.score.points, pinnedCountPoints);
    expect(count.score.totalMs, pinnedCountMs);
  });

  test('a question mode: about 70 % right, in the tier\'s fluent range', () {
    var right = 0;
    var total = 0;
    for (var seed = 0; seed < 200; seed++) {
      final config = _duel(DuelMode.advanced, seed, 3);
      final lane = practiceLane(config) as QuizLane;
      expect(lane.answers.length, duelQuestionCount);
      for (final (i, type) in config.typeSequence().indexed) {
        final a = lane.answers[i];
        total++;
        if (a.correct) right++;
        // 60–140 % of the question's own fluent time at T3.
        final fluent = fluentTimeMs(type, Level.whole(30), RulesVersion.v8);
        expect(a.elapsedMs, inInclusiveRange(fluent * 0.6, fluent * 1.4));
      }
    }
    expect(right / total, closeTo(0.7, 0.05));
  });

  test('Get the count: exact or a little off, closer over time, in 8–28 s', () {
    var exact = 0;
    var rounds = 0;
    for (var seed = 0; seed < 100; seed++) {
      final lane = practiceLane(_duel(DuelMode.count, seed, 1)) as CountLane;
      expect(lane.rounds.length, countDuelRounds);
      for (final round in lane.rounds) {
        rounds++;
        if (round.distance == 0) exact++;
        expect(round.distance, lessThanOrEqualTo(round.baseDistance));
        var last = round.baseDistance;
        var lastMs = -1;
        for (final imp in round.improvements) {
          expect(imp.distance, lessThan(last));
          expect(imp.atMs, greaterThan(lastMs));
          expect(imp.atMs, lessThanOrEqualTo(28000));
          last = imp.distance;
          lastMs = imp.atMs;
        }
      }
    }
    expect(exact / rounds, closeTo(0.5, 0.1));
  });

  test('another seed, another lane', () {
    expect(
      practiceLane(_duel(DuelMode.basics, 2, 4)).toJson(),
      isNot(practiceLane(_duel(DuelMode.basics, 1, 4)).toJson()),
    );
  });
}

const pinnedQuizPoints = 5;
const pinnedQuizMs = 75700;
const pinnedCountPoints = 0;
const pinnedCountMs = 39524;
