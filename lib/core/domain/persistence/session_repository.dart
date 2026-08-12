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

  /// Temps de réponse moyen par opération, tout l'historique de [playerId]
  /// confondu. Timeouts inclus sans exclusion — mêmes règles que
  /// `SessionResult.averageElapsedMs` (déjà utilisé sur l'écran de résultat),
  /// pour que les deux écrans racontent la même chose. Agrégée en SQL côté
  /// `sqflite` : ne dégrade pas avec le volume d'historique, contrairement à
  /// un `answersForSession` appelé une fois par session (`doc/decisions.md`
  /// — « charger l'historique sans le charger entièrement »).
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId);

  /// Sessions de [playerId] créées à partir de [since] (borne incluse),
  /// triées du plus ancien au plus récent. Fenêtre bornée par date plutôt
  /// qu'agrégation SQL : `levels` est stocké en JSON, donc aucune colonne
  /// numérique à agréger pour reconstituer un niveau par opération à un
  /// instant donné — mais la lecture reste bornée, jamais un historique
  /// complet.
  Future<List<PersistedSession>> sessionsSince(String playerId, DateTime since);
}
