import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/generation/exercise_source.dart';
import '../domain/leveling/answer_outcome.dart';
import '../domain/leveling/confidence.dart';
import '../domain/leveling/level_cache_entry.dart';
import '../domain/leveling/level_updater.dart';
import '../domain/models/answer_result.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/session_config.dart';
import '../domain/models/session_result.dart';
import '../domain/persistence/exercise_codec.dart';
import '../domain/persistence/persisted_answer.dart';
import '../domain/persistence/persisted_session.dart';
import '../domain/persistence/session_repository.dart';
import '../domain/persistence/uuid.dart';
import '../domain/scoring/scorer.dart';
import 'session_state.dart';

/// Orchestration de la session : source d'exercices + scoring + persistance
/// à la fin de la session. Dépend d'interfaces (`ExerciseSource`,
/// `SessionRepository`), jamais d'une implémentation concrète, pour que le
/// duel ou un futur backend puissent les remplacer sans changer cette classe
/// ni l'UI qui l'observe.
///
/// `ChangeNotifier` vient de `flutter/foundation.dart` : c'est un objet
/// observable natif au SDK Flutter (pas un widget). `notifyListeners()`
/// prévient tout widget qui écoute (via `ListenableBuilder`) qu'il doit se
/// reconstruire.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.config,
    required this.exerciseSource,
    required this.repository,
    required this.playerId,
    this.scorer = const Scorer(),
    this.clock = DateTime.now,
    this.idGenerator = generateUuidV4,
    LevelUpdater? levelUpdater,
  }) : levelUpdater = levelUpdater ?? LevelUpdater();

  final SessionConfig config;
  final ExerciseSource exerciseSource;
  final LevelUpdater levelUpdater;
  final SessionRepository repository;
  final String playerId;
  final Scorer scorer;
  final DateTime Function() clock;
  final String Function() idGenerator;

  SessionState _state = SessionState.initial();
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

  void submitAnswer(int submittedValue) {
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

    if (isSessionComplete) {
      unawaited(_persistCompletedSession());
    }
  }

  SessionResult get result => SessionResult(outcomes: _state.outcomes, totalScore: _state.score);

  void restart() {
    _state = SessionState.initial();
    _questionStartedAt = null;
    notifyListeners();
  }

  Future<void> _persistCompletedSession() async {
    final sessionId = idGenerator();
    final createdAt = clock().toUtc();

    final answers = _state.outcomes.map((outcome) {
      final described = describeExerciseForStorage(outcome.exercise);
      return PersistedAnswer(
        id: idGenerator(),
        sessionId: sessionId,
        exerciseType: described.exerciseType,
        operationType: described.operationType,
        operands: described.operands,
        submittedValue: outcome.submittedValue,
        isCorrect: outcome.isCorrect,
        elapsedMs: outcome.elapsedMs,
        createdAt: createdAt,
      );
    }).toList();

    final session = PersistedSession(
      id: sessionId,
      playerId: playerId,
      seed: config.seed,
      enabledTypes: config.enabledTypes,
      exerciseCount: config.exerciseCount,
      totalScore: _state.score,
      levels: config.levels,
      createdAt: createdAt,
    );

    try {
      final levelUpdates = await _computeLevelUpdates(createdAt);
      await repository.recordSession(
        session: session,
        answers: answers,
        levelUpdates: levelUpdates,
      );
    } catch (_) {
      // La persistance ne doit jamais casser la partie en cours : échec
      // silencieux pour le MVP (pas de file d'attente/retry — hors périmètre).
    }
  }

  /// Une entrée par type activé ayant reçu au moins `n_min` réponses cette
  /// session (les autres sont un échantillon de bruit, voir
  /// `doc/decisions.md` — leur cache n'est pas touché). Le niveau de départ
  /// utilisé est celui qui a réellement servi à générer la session
  /// (`config.levels`), jamais relu depuis le cache à cet instant.
  Future<Map<ExerciseType, LevelCacheEntry>> _computeLevelUpdates(DateTime now) async {
    final outcomesByType = <ExerciseType, List<AnswerOutcome>>{};
    for (final outcome in _state.outcomes) {
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
      final currentLevel = config.levels[type] ?? 1;
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
