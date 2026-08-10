import 'level_cache_entry.dart';
import '../models/exercise_type.dart';
import 'persisted_answer.dart';
import 'persisted_session.dart';

/// Le domaine ne connaît jamais l'implémentation du stockage (sqflite,
/// mémoire, ...) — seulement cette interface. Toutes les méthodes sont
/// asynchrones même quand une implémentation locale est synchrone, pour ne
/// pas avoir à réécrire la chaîne d'appel le jour où le réseau entre en jeu.
abstract class SessionRepository {
  /// Écrit [session], [answers] et la mise à jour du cache de niveaux en une
  /// seule opération atomique : le cache ne doit jamais être en avance ou en
  /// retard sur la session qui l'a produit.
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  });

  Future<List<PersistedSession>> recentSessions({int limit = 20});

  Future<List<PersistedAnswer>> answersForSession(String sessionId);

  /// État actuel du cache de niveaux pour [playerId]. N'inclut que les
  /// opérations déjà jouées au moins une fois — à l'appelant de décider du
  /// niveau par défaut pour une opération absente (voir `doc/decisions.md`).
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId);
}
