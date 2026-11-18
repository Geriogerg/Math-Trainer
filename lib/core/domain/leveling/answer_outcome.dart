/// Everything [LevelUpdater] needs from an answer: neither the live
/// gameplay [Exercise] nor the persistence fields (id, timestamps) of a
/// stored answer. `AnswerResult` and `PersistedAnswer` convert trivially to
/// this type, without this file having to know them.
class AnswerOutcome {
  const AnswerOutcome({required this.isCorrect, required this.elapsedMs});

  final bool isCorrect;
  final int elapsedMs;
}
