import '../models/answer_result.dart';
import '../models/exercise_type.dart';
import '../persistence/level_cache_entry.dart';
import '../persistence/session_repository.dart';
import 'answer_outcome.dart';
import 'confidence.dart';
import 'level_updater.dart';

/// Calcule les mises à jour du cache de niveaux en fin de session. Sorti de
/// `SessionController` (étape 4.1, commit D) pour rester du Dart pur,
/// réexécutable côté serveur (règle 1) — c'est exactement ce que la
/// revalidation d'un duel devra un jour refaire.
class LevelCacheOrchestrator {
  LevelCacheOrchestrator({LevelUpdater? levelUpdater})
    : levelUpdater = levelUpdater ?? LevelUpdater();

  final LevelUpdater levelUpdater;

  /// Une entrée par type activé ayant reçu au moins `n_min` réponses cette
  /// session (les autres sont un échantillon de bruit, voir
  /// `doc/decisions.md` — leur cache n'est pas touché). [frozenLevels] est
  /// le niveau qui a réellement servi à générer la session, jamais relu
  /// depuis le cache à cet instant.
  Future<Map<ExerciseType, LevelCacheEntry>> computeUpdates({
    required List<AnswerResult> outcomes,
    required Map<ExerciseType, int> frozenLevels,
    required SessionRepository repository,
    required String playerId,
    required DateTime now,
  }) async {
    final outcomesByType = <ExerciseType, List<AnswerOutcome>>{};
    for (final outcome in outcomes) {
      outcomesByType
          .putIfAbsent(outcome.exercise.type, () => [])
          .add(AnswerOutcome(isCorrect: outcome.isCorrect, elapsedMs: outcome.elapsedMs));
    }

    final priorLevels = await repository.currentLevels(playerId);
    final updates = <ExerciseType, LevelCacheEntry>{};

    for (final entry in outcomesByType.entries) {
      final type = entry.key;
      final answers = entry.value;
      if (answers.length < levelUpdater.rules.nMin) continue;

      final prior = priorLevels[type];
      final currentLevel = frozenLevels[type] ?? 1;
      final confidence = confidenceFor(entry: prior, now: now, rules: levelUpdater.rules);
      final newLevel = levelUpdater.update(
        currentLevel: currentLevel,
        answers: answers,
        confidence: confidence,
      );

      updates[type] = LevelCacheEntry(
        level: newLevel,
        sessionsPlayed: (prior?.sessionsPlayed ?? 0) + 1,
        updatedAt: now,
      );
    }

    return updates;
  }
}
