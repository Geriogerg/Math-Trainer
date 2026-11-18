import '../models/exercise_type.dart';
import 'type_selection_strategy.dart';

/// Solo strategy: least-played types first (lowest `sessionsPlayed` in
/// `player_levels`), with no dedicated counter — the input is already
/// stored, recomputable server-side. See `doc/decisions.md`.
class DebtAwareTypeSelectionStrategy implements TypeSelectionStrategy {
  DebtAwareTypeSelectionStrategy({
    required this.exerciseCount,
    required this.nMin,
    required this.sessionsPlayedByType,
  });

  final int exerciseCount;
  final int nMin;
  final Map<ExerciseType, int> sessionsPlayedByType;

  @override
  List<ExerciseType> sequenceFor(List<ExerciseType> sortedEnabledTypes) {
    // `List.sort` is not guaranteed stable in Dart: equal debt is broken
    // explicitly by `.index` (that of `sortedEnabledTypes`), never left to
    // the sort algorithm.
    final priority = [...sortedEnabledTypes]..sort((a, b) {
      final byDebt = (sessionsPlayedByType[a] ?? 0).compareTo(sessionsPlayedByType[b] ?? 0);
      return byDebt != 0 ? byDebt : a.index.compareTo(b.index);
    });

    final fullBlockCount = _min(exerciseCount ~/ nMin, priority.length);
    final quotas = <ExerciseType, int>{
      for (final type in priority.take(fullBlockCount)) type: nMin,
    };

    var remaining = exerciseCount - fullBlockCount * nMin;
    // The remainder goes first to types that did not get a full block; if
    // every active type has one (budget larger than n_min × number of
    // types), there is nobody else to give it to: the already full types
    // get the surplus as a bonus rather than leaving `remaining`
    // undistributed (which would block the interleaving below).
    final remainderCandidates = priority.skip(fullBlockCount).toList();
    final remainderPool = remainderCandidates.isNotEmpty ? remainderCandidates : priority;
    var i = 0;
    while (remaining > 0) {
      final type = remainderPool[i % remainderPool.length];
      quotas[type] = (quotas[type] ?? 0) + 1;
      remaining--;
      i++;
    }

    final sequence = <ExerciseType>[];
    final remainingQuota = Map<ExerciseType, int>.of(quotas);
    while (sequence.length < exerciseCount) {
      for (final type in priority) {
        if ((remainingQuota[type] ?? 0) > 0) {
          sequence.add(type);
          remainingQuota[type] = remainingQuota[type]! - 1;
          if (sequence.length == exerciseCount) break;
        }
      }
    }
    return sequence;
  }

  int _min(int a, int b) => a < b ? a : b;
}
