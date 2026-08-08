import 'package:flutter/foundation.dart';

import '../domain/generation/exercise_source.dart';
import '../domain/models/answer_result.dart';
import '../domain/models/session_config.dart';
import '../domain/models/session_result.dart';
import '../domain/scoring/scorer.dart';
import 'session_state.dart';

/// Orchestration de la session : source d'exercices + scoring. Dépend de
/// `ExerciseSource` (interface), pas d'une implémentation concrète, pour que
/// le duel puisse brancher une source réseau plus tard sans changer cette
/// classe ni l'UI qui l'observe.
///
/// `ChangeNotifier` vient de `flutter/foundation.dart` : c'est un objet
/// observable natif au SDK Flutter (pas un widget). `notifyListeners()`
/// prévient tout widget qui écoute (via `ListenableBuilder`) qu'il doit se
/// reconstruire.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.config,
    required this.exerciseSource,
    this.scorer = const Scorer(),
    this.clock = DateTime.now,
  }) : _state = SessionState.initial();

  final SessionConfig config;
  final ExerciseSource exerciseSource;
  final Scorer scorer;
  final DateTime Function() clock;

  SessionState _state;
  SessionState get state => _state;

  DateTime? _questionStartedAt;

  void start() {
    _state = SessionState(
      status: SessionStatus.inProgress,
      currentExercise: exerciseSource.next(),
    );
    _questionStartedAt = clock();
    notifyListeners();
  }

  void submitAnswer(num submittedValue) {
    final exercise = _state.currentExercise;
    if (_state.status != SessionStatus.inProgress || exercise == null) return;

    final elapsedMs = clock().difference(_questionStartedAt!).inMilliseconds;
    final isCorrect = exercise.isCorrectAnswer(submittedValue);
    final nextStreak = isCorrect ? _state.currentStreak + 1 : 0;

    final outcome = AnswerResult(
      exercise: exercise,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
    );
    final points = scorer.pointsFor(outcome, currentStreak: nextStreak);
    final outcomes = [..._state.outcomes, outcome];
    final isSessionComplete = outcomes.length >= config.exerciseCount;

    _state = SessionState(
      status: isSessionComplete ? SessionStatus.finished : SessionStatus.inProgress,
      currentExercise: isSessionComplete ? null : exerciseSource.next(),
      outcomes: outcomes,
      score: _state.score + points,
      currentStreak: nextStreak,
    );
    _questionStartedAt = clock();
    notifyListeners();
  }

  SessionResult get result => SessionResult(outcomes: _state.outcomes, totalScore: _state.score);

  void restart() {
    _state = SessionState.initial();
    _questionStartedAt = null;
    notifyListeners();
  }
}
