import '../domain/models/answer_result.dart';
import '../domain/models/exercise.dart';

/// `interrupted` : trois timeouts consécutifs sans aucune touche pressée
/// (étape 4.2, commit B — voir `doc/decisions.md`). Distinct de `finished` :
/// la session n'est pas comptabilisée pour les niveaux, même si les réponses
/// déjà données restent enregistrées.
enum SessionStatus { notStarted, inProgress, finished, interrupted }

class SessionState {
  const SessionState({
    required this.status,
    this.currentExercise,
    this.outcomes = const [],
    this.score = 0,
    this.currentStreak = 0,
  });

  factory SessionState.initial() => const SessionState(status: SessionStatus.notStarted);

  final SessionStatus status;
  final Exercise? currentExercise;
  final List<AnswerResult> outcomes;
  final int score;
  final int currentStreak;
}
