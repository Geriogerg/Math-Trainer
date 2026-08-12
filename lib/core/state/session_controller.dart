import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/generation/exercise_source.dart';
import '../domain/leveling/level_cache_orchestrator.dart';
import '../domain/models/answer_result.dart';
import '../domain/models/exercise.dart';
import '../domain/models/exercise_type.dart';
import '../domain/models/session_config.dart';
import '../domain/models/session_result.dart';
import '../domain/persistence/exercise_codec.dart';
import '../domain/persistence/level_cache_entry.dart';
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
    this.createTimer = Timer.new,
    this.questionTimeout = const Duration(seconds: 15),
    LevelCacheOrchestrator? levelCacheOrchestrator,
  }) : levelCacheOrchestrator = levelCacheOrchestrator ?? LevelCacheOrchestrator();

  final SessionConfig config;
  final ExerciseSource exerciseSource;
  final LevelCacheOrchestrator levelCacheOrchestrator;
  final SessionRepository repository;
  final String playerId;
  final Scorer scorer;
  final DateTime Function() clock;
  final String Function() idGenerator;

  /// Injectable pour les tests (même esprit que [clock]/[idGenerator]) — un
  /// vrai `Timer` de 15 s ne doit jamais tourner pendant un test.
  final Timer Function(Duration duration, void Function() callback) createTimer;
  final Duration questionTimeout;

  /// Trois timeouts consécutifs sans aucune touche pressée interrompent la
  /// session (`doc/decisions.md`).
  static const _abandonThreshold = 3;

  SessionState _state = SessionState.initial();
  SessionState get state => _state;

  DateTime? _questionStartedAt;
  Timer? _timeoutTimer;
  bool _hasActivityThisQuestion = false;
  int _consecutiveTimeoutsWithoutActivity = 0;

  void start() {
    _state = SessionState(
      status: SessionStatus.inProgress,
      currentExercise: exerciseSource.next(),
    );
    _questionStartedAt = clock();
    _scheduleTimeout();
    notifyListeners();
  }

  /// Appelée par l'écran à chaque touche du pavé — chiffre *ou* retour
  /// arrière, pas seulement Valider. C'est ce qui distingue « a essayé » de
  /// « n'a rien touché » pour l'interruption pour abandon : un timeout après
  /// une saisie jamais validée ne compte pas comme un abandon.
  void registerActivity() {
    _hasActivityThisQuestion = true;
  }

  void _scheduleTimeout() {
    _timeoutTimer?.cancel();
    _hasActivityThisQuestion = false;
    _timeoutTimer = createTimer(questionTimeout, _onTimeout);
  }

  void _onTimeout() {
    final exercise = _state.currentExercise;
    if (_state.status != SessionStatus.inProgress || exercise == null) return;

    final hadActivity = _hasActivityThisQuestion;
    _recordOutcome(
      exercise: exercise,
      submittedValue: timeoutSubmittedValue,
      isCorrect: false,
      elapsedMs: questionTimeout.inMilliseconds,
    );

    if (hadActivity) {
      _consecutiveTimeoutsWithoutActivity = 0;
      return;
    }
    _consecutiveTimeoutsWithoutActivity++;
    // La complétion prime : si ce timeout tombe pile sur la dernière
    // question, _recordOutcome vient de passer le statut à `finished` —
    // la session se termine normalement, elle ne s'interrompt pas.
    if (_consecutiveTimeoutsWithoutActivity >= _abandonThreshold &&
        _state.status == SessionStatus.inProgress) {
      _interruptSession();
    }
  }

  void submitAnswer(int submittedValue) {
    final exercise = _state.currentExercise;
    if (_state.status != SessionStatus.inProgress || exercise == null) return;

    final isCorrect = exercise.isCorrectAnswer(submittedValue);
    _consecutiveTimeoutsWithoutActivity = 0;
    _recordOutcome(
      exercise: exercise,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: clock().difference(_questionStartedAt!).inMilliseconds,
    );
  }

  /// Calcule score/streak, avance à la question suivante ou termine la
  /// session, notifie, et déclenche la persistance si la session se
  /// termine. Partagé entre [submitAnswer] et [_onTimeout] : un timeout
  /// suit exactement le même chemin qu'une réponse fausse, seule
  /// [submittedValue] change.
  void _recordOutcome({
    required Exercise exercise,
    required int submittedValue,
    required bool isCorrect,
    required int elapsedMs,
  }) {
    final nextStreak = isCorrect ? _state.currentStreak + 1 : 0;

    final outcome = AnswerResult(
      exercise: exercise,
      submittedValue: submittedValue,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
    );
    final points = scorer.pointsFor(
      outcome,
      currentStreak: nextStreak,
      level: config.levels[exercise.type] ?? 1,
    );
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

    if (isSessionComplete) {
      _timeoutTimer?.cancel();
    } else {
      _scheduleTimeout();
    }
    notifyListeners();

    if (isSessionComplete) {
      unawaited(_persistCompletedSession(countsForLevels: true));
    }
  }

  void _interruptSession() {
    _timeoutTimer?.cancel();
    _state = SessionState(
      status: SessionStatus.interrupted,
      outcomes: _state.outcomes,
      score: _state.score,
      currentStreak: _state.currentStreak,
    );
    notifyListeners();
    unawaited(_persistCompletedSession(countsForLevels: false));
  }

  SessionResult get result => SessionResult(outcomes: _state.outcomes, totalScore: _state.score);

  void restart() {
    _timeoutTimer?.cancel();
    _state = SessionState.initial();
    _questionStartedAt = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  /// [countsForLevels] : `false` pour une session interrompue (abandon) —
  /// la session et les réponses déjà données sont quand même enregistrées
  /// (non reconstructibles autrement), seul le calcul du cache de niveaux
  /// est sauté. `PersistedSession.exerciseCount` reste le compte *prévu* ;
  /// `answers.length < exerciseCount` suffit à reconnaître une session
  /// interrompue plus tard, sans champ supplémentaire à persister.
  Future<void> _persistCompletedSession({required bool countsForLevels}) async {
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

    var levelUpdates = const <ExerciseType, LevelCacheEntry>{};
    if (countsForLevels) {
      try {
        levelUpdates = await levelCacheOrchestrator.computeUpdates(
          outcomes: _state.outcomes,
          frozenLevels: config.levels,
          repository: repository,
          playerId: playerId,
          now: createdAt,
        );
      } on Exception catch (_) {
        // Le cache de niveaux est recalculable depuis l'historique (voir
        // doc/decisions.md) : une lecture ratée ne doit pas empêcher
        // l'enregistrement de la session, qui lui n'est reconstructible nulle
        // part ailleurs — priorité à ce qui n'est pas reconstructible.
        //
        // `on Exception`, pas `catch (_)` : un `Error` (ArgumentError,
        // StateError...) signale un bug — un invariant qui lève quelque part
        // dans cette chaîne (LevelUpdater, LevelCacheEntry, LevelingRules...)
        // doit rester visible, pas être avalé au même titre qu'un échec
        // réseau/disque. C'est exactement ce que la règle 13 défend : un
        // catch trop large réintroduirait le même problème qu'un `assert`
        // supprimé en release, côté try/catch cette fois.
      }
    }

    try {
      await repository.recordSession(
        session: session,
        answers: answers,
        levelUpdates: levelUpdates,
      );
    } on Exception catch (_) {
      // La persistance ne doit jamais casser la partie en cours : échec
      // silencieux pour le MVP (pas de file d'attente/retry — hors périmètre).
    }
  }
}
