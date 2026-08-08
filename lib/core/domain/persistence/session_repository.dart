import 'persisted_answer.dart';
import 'persisted_session.dart';

/// Le domaine ne connaît jamais l'implémentation du stockage (sqflite,
/// mémoire, ...) — seulement cette interface. Toutes les méthodes sont
/// asynchrones même quand une implémentation locale est synchrone, pour ne
/// pas avoir à réécrire la chaîne d'appel le jour où le réseau entre en jeu.
abstract class SessionRepository {
  /// Écrit [session] et [answers] en une seule opération atomique : une
  /// session sans ses réponses (ou l'inverse) ne doit jamais pouvoir exister.
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
  });

  Future<List<PersistedSession>> recentSessions({int limit = 20});

  Future<List<PersistedAnswer>> answersForSession(String sessionId);
}
