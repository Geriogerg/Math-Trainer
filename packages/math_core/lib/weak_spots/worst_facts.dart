import '../leveling/level.dart';
import '../leveling/rules_version.dart';
import '../persistence/exercise_codec.dart';
import '../persistence/session_repository.dart';
import 'history.dart';
import 'item.dart';
import 'item_of.dart';

/// How a fact went over the whole history (Profile's "Weak spots" block,
/// Phase 4).
final class WeakFact {
  const WeakFact({
    required this.fact,
    required this.answers,
    required this.misses,
    required this.meanCorrectMs,
    required this.fluentMs,
  });

  final FactItem fact;
  final int answers;

  /// Wrong answers and timeouts.
  final int misses;

  /// Mean time of the correct answers; `null` when none was correct.
  final int? meanCorrectMs;

  /// The fact's own fluent time (`itemFluentMs`).
  final int fluentMs;

  /// Slower than fluent on average, by this factor (0 when never right).
  double get slowness => meanCorrectMs == null ? 0 : meanCorrectMs! / fluentMs;
}

/// The [count] worst facts of [games] (`doc/decisions.md`, "Phase 4"):
/// facts answered at least twice; the most missed first (miss rate, then
/// misses), then the slowest against their fluent time — a fact never
/// missed and fluent on average is no weak spot and is left out. Ties by
/// key.
List<WeakFact> worstFacts(Iterable<StoredGame> games, {int count = 5}) {
  final answers = <FactItem, int>{};
  final misses = <FactItem, int>{};
  final correctMs = <FactItem, int>{};
  final corrects = <FactItem, int>{};
  for (final game in games) {
    for (final a in game.answers) {
      final exercise = exerciseFromStorage(
        exerciseType: a.exerciseType,
        operationType: a.operationType,
        operands: a.operands,
      );
      // Read as a standard question: the Profile lists facts as the
      // player saw them, a fact-sized pattern question (2⁸) included.
      final item = itemOf(exercise);
      if (item is! FactItem) continue;
      answers[item] = (answers[item] ?? 0) + 1;
      if (a.isCorrect) {
        corrects[item] = (corrects[item] ?? 0) + 1;
        correctMs[item] = (correctMs[item] ?? 0) + a.elapsedMs;
      } else {
        misses[item] = (misses[item] ?? 0) + 1;
      }
    }
  }
  final records = [
    for (final MapEntry(key: fact, value: n) in answers.entries)
      if (n >= 2)
        WeakFact(
          fact: fact,
          answers: n,
          misses: misses[fact] ?? 0,
          meanCorrectMs: switch (corrects[fact]) {
            null => null,
            final c => correctMs[fact]! ~/ c,
          },
          // A fact's own: where it was asked and under which rules do not
          // matter.
          fluentMs: itemFluentMs(
            fact,
            drawnAt: Level.zero,
            rules: RulesVersion.current,
          ),
        ),
  ].where((r) => r.misses > 0 || r.slowness > 1).toList();
  records.sort((a, b) {
    // Missed before merely slow.
    if ((a.misses > 0) != (b.misses > 0)) return a.misses > 0 ? -1 : 1;
    if (a.misses > 0) {
      final byRate = (b.misses * a.answers).compareTo(a.misses * b.answers);
      if (byRate != 0) return byRate;
      final byMisses = b.misses.compareTo(a.misses);
      if (byMisses != 0) return byMisses;
    } else {
      final bySlowness = b.slowness.compareTo(a.slowness);
      if (bySlowness != 0) return bySlowness;
    }
    return a.fact.compareTo(b.fact);
  });
  return records.take(count).toList();
}
