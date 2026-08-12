import 'exercise.dart';

/// Sentinelle pour « aucune valeur saisie, la question a expiré ». Jamais une
/// vraie réponse : le pavé n'a pas de touche `−` et aucune opération ne
/// produit de réponse correcte négative (soustraction garantie
/// `operandA ≥ operandB`, toutes les autres sur des opérandes positifs) —
/// voir `doc/decisions.md`. Évite de rendre `submittedValue` nullable, ce qui
/// aurait exigé une migration de schéma (`answers.submitted_value` est
/// `REAL NOT NULL`).
const timeoutSubmittedValue = -1;

class AnswerResult {
  const AnswerResult({
    required this.exercise,
    required this.submittedValue,
    required this.isCorrect,
    required this.elapsedMs,
  });

  final Exercise exercise;
  final int submittedValue;
  final bool isCorrect;
  final int elapsedMs;

  bool get isTimeout => submittedValue == timeoutSubmittedValue;

  @override
  bool operator ==(Object other) =>
      other is AnswerResult &&
      other.exercise == exercise &&
      other.submittedValue == submittedValue &&
      other.isCorrect == isCorrect &&
      other.elapsedMs == elapsedMs;

  @override
  int get hashCode =>
      Object.hash(exercise, submittedValue, isCorrect, elapsedMs);
}
