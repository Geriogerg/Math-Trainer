import '../models/exercise_type.dart';
import 'type_selection_strategy.dart';

/// Stratégie solo : priorité aux types les moins joués (`sessionsPlayed` le
/// plus bas dans `player_levels`), sans aucun compteur dédié — l'entrée est
/// déjà en base, recalculable côté serveur. Voir `doc/decisions.md`.
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
    // `List.sort` n'est pas garanti stable en Dart : l'égalité de dette est
    // tranchée explicitement par `.index` (celui de `sortedEnabledTypes`),
    // jamais laissée à l'algorithme de tri.
    final priority = [...sortedEnabledTypes]..sort((a, b) {
      final byDebt = (sessionsPlayedByType[a] ?? 0).compareTo(sessionsPlayedByType[b] ?? 0);
      return byDebt != 0 ? byDebt : a.index.compareTo(b.index);
    });

    final fullBlockCount = _min(exerciseCount ~/ nMin, priority.length);
    final quotas = <ExerciseType, int>{
      for (final type in priority.take(fullBlockCount)) type: nMin,
    };

    var remaining = exerciseCount - fullBlockCount * nMin;
    // Le reste va d'abord aux types qui n'ont pas eu de bloc complet ; si
    // tous les types actifs en ont un (budget plus grand que n_min ×
    // nombre de types), il n'y a personne d'autre à qui le donner : les
    // types déjà pleins reçoivent le surplus en bonus plutôt que de laisser
    // remaining non distribué (ce qui bloquerait l'entrelacement plus bas).
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
