/// Tout ce dont [LevelUpdater] a besoin d'une réponse : ni l'[Exercise] du
/// gameplay live, ni les champs de persistance (id, timestamps) d'une
/// réponse stockée. `AnswerResult` et `PersistedAnswer` se convertissent
/// trivialement vers ce type, sans que ce fichier ait à les connaître.
class AnswerOutcome {
  const AnswerOutcome({required this.isCorrect, required this.elapsedMs});

  final bool isCorrect;
  final int elapsedMs;
}
