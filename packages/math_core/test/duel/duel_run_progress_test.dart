import 'package:math_core/challenges/count.dart';
import 'package:math_core/duel/duel_run.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:test/test.dart';

/// Phase 6a commit 1 (plan v3.9): what the server uses to refuse a second
/// go at the same questions (`continues`) and a faked time (`claimedMs`).
/// Pure, the same on the VM and in JavaScript.
void main() {
  DuelAnswer a(int value, int ms) => DuelAnswer(value: value, elapsedMs: ms);
  CountImprovement imp(int atMs, int value) => CountImprovement(
    atMs: atMs,
    value: value,
    steps: [CountStep(value - 1, CountOperator.add, 1, value)],
  );

  group('QuizRun.continues', () {
    final progress = QuizRun([a(12, 3100), a(7, 2500), a(40, 9000)]);

    test('the same answers and times, then more', () {
      expect(progress.continues(progress), isTrue);
      expect(
        QuizRun([...progress.answers, a(5, 1200)]).continues(progress),
        isTrue,
      );
      expect(progress.completedWithTimeouts().continues(progress), isTrue);
      expect(progress.continues(QuizRun(const [])), isTrue);
    });

    test('a changed answer, a changed time, fewer answers, another mode', () {
      expect(
        QuizRun([a(13, 3100), a(7, 2500), a(40, 9000)]).continues(progress),
        isFalse,
        reason: 'another answer to the first question',
      );
      expect(
        QuizRun([a(12, 3100), a(7, 2499), a(40, 9000)]).continues(progress),
        isFalse,
        reason: 'another time',
      );
      expect(
        QuizRun(progress.answers.take(2).toList()).continues(progress),
        isFalse,
        reason: 'what was received is never taken back',
      );
      expect(CountRun(const []).continues(progress), isFalse);
    });
  });

  group('CountRun.continues', () {
    final first = CountRoundRun([imp(4000, 95), imp(9000, 99)]);
    final progress = CountRun([first]);

    test('the rounds received, unchanged, then more', () {
      expect(
        CountRun([
          CountRoundRun([imp(4000, 95), imp(9000, 99)]),
          CountRoundRun([imp(2000, 50)]),
        ]).continues(progress),
        isTrue,
      );
      expect(progress.completedWithEmptyRounds().continues(progress), isTrue);
    });

    test('a finished round is never improved afterwards', () {
      expect(
        CountRun([
          CountRoundRun([imp(4000, 95), imp(9000, 99), imp(20000, 100)]),
        ]).continues(progress),
        isFalse,
        reason: 'one more improvement in a round already received',
      );
      expect(
        CountRun([
          CountRoundRun([imp(4000, 95), imp(8000, 99)]),
        ]).continues(progress),
        isFalse,
      );
      expect(CountRun(const []).continues(progress), isFalse);
      expect(QuizRun(const []).continues(progress), isFalse);
    });

    test('improvements compare by time, value and steps', () {
      expect(imp(1, 2), imp(1, 2));
      expect(imp(1, 2).hashCode, imp(1, 2).hashCode);
      expect(
        imp(1, 2),
        isNot(CountImprovement(atMs: 1, value: 2, steps: const [])),
      );
      expect(CountRoundRun([imp(1, 2)]), CountRoundRun([imp(1, 2)]));
    });
  });

  group('claimedMs — the time a run says was spent answering', () {
    test('answers count; unanswered questions do not', () {
      final played = QuizRun([a(12, 3100), a(7, 2500)]);
      expect(played.claimedMs, 5600);
      expect(
        played.completedWithTimeouts().claimedMs,
        5600,
        reason: 'the app fills timeouts in without waiting 30 s each',
      );
      expect(QuizRun([a(timeoutSubmittedValue, 30000)]).claimedMs, 0);
      expect(QuizRun(const []).claimedMs, 0);
    });

    test('a count round lasted at least until its last improvement', () {
      expect(
        CountRun([
          CountRoundRun([imp(4000, 95), imp(9000, 99)]),
          CountRoundRun(const []),
          CountRoundRun([imp(2500, 10)]),
        ]).claimedMs,
        11500,
      );
    });
  });
}
