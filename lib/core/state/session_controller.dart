import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/generation/exercise_source.dart';
import '../domain/leveling/level_cache_orchestrator.dart';
import '../domain/leveling/overall_level.dart';
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

/// Écriture de fin de session, gardée telle quelle si elle échoue pour que
/// [SessionController.retryPersistence] la rejoue à l'identique.
typedef _SessionWrite = ({
  PersistedSession session,
  List<PersistedAnswer> answers,
  Map<ExerciseType, LevelCacheEntry> levelUpdates,
});

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
  Future<void>? _pendingPersistence;
  Map<ExerciseType, LevelCacheEntry>? _lastLevelUpdates;
  bool _persistenceFailed = false;
  _SessionWrite? _failedWrite;
  bool _isRetryingPersistence = false;
  bool _isDisposed = false;

  /// L'enregistrement de fin de session a échoué : la partie n'est pas dans
  /// l'historique et les niveaux n'ont pas bougé. Affiché sur l'écran de
  /// résultat — sans ça, le joueur croirait sa progression comptée.
  bool get persistenceFailed => _persistenceFailed;

  /// Un nouvel essai ([retryPersistence]) est en cours.
  bool get isRetryingPersistence => _isRetryingPersistence;

  /// Rejoue l'écriture qui a échoué, à l'identique (mêmes ids) :
  /// `recordSession` est atomique, un échec n'a rien laissé derrière lui,
  /// donc rien ne peut être écrit deux fois. Remplace [pendingPersistence]
  /// pour que la sortie de l'écran de résultat attende aussi cet essai avant
  /// de relire les niveaux. Sans effet s'il n'y a rien à rejouer.
  Future<void> retryPersistence() async {
    final write = _failedWrite;
    if (write == null || _isRetryingPersistence) return;
    _isRetryingPersistence = true;
    _notifyIfAlive();
    final attempt = _record(write);
    _pendingPersistence = attempt;
    await attempt;
    _isRetryingPersistence = false;
    _notifyIfAlive();
  }

  /// L'écriture de fin de session continue après la fermeture de l'écran
  /// (« Nouvelle sélection » juste après la dernière réponse dispose le
  /// contrôleur) : notifier un `ChangeNotifier` disposé lève en debug, et
  /// cette erreur interrompait l'écriture avant `recordSession` — partie
  /// perdue.
  void _notifyIfAlive() {
    if (!_isDisposed) notifyListeners();
  }

  /// Niveaux mis à jour par la session qui vient de se terminer — `null`
  /// tant que le calcul asynchrone (`_persistCompletedSession`) n'a pas
  /// résolu, ou après une session interrompue (jamais calculé, voir
  /// `countsForLevels`). Absent de `outcomes`, donc pas reconstituible
  /// autrement : sert à l'écran de résultat pour animer le changement de
  /// niveau (`doc/design.md`, `AppMotion.levelUp`).
  Map<ExerciseType, LevelCacheEntry>? get lastLevelUpdates => _lastLevelUpdates;

  /// Se résout quand l'écriture de fin de session (réponses + éventuelle
  /// mise à jour du cache de niveaux) est terminée. Une relance immédiate
  /// doit l'attendre avant de relire les niveaux — `_persistCompletedSession`
  /// tourne en tâche de fond, sans ça `buildSessionController` pourrait lire
  /// les niveaux d'*avant* la session qui vient de se terminer.
  Future<void> get pendingPersistence => _pendingPersistence ?? Future<void>.value();

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
      _pendingPersistence = _persistCompletedSession(countsForLevels: true);
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
    // Abandon avant toute réponse (seul cas possible : un timeout enregistre
    // toujours une réponse) — rien à conserver, et une session vide
    // apparaîtrait comme une partie à 0 point dans l'historique du Profil.
    if (_state.outcomes.isEmpty) return;
    _pendingPersistence = _persistCompletedSession(countsForLevels: false);
  }

  /// Abandon manuel (retour Android confirmé, étape 5 commit A) : même
  /// traitement qu'une interruption automatique — statut `interrupted`,
  /// réponses déjà données persistées, cache de niveaux non touché. Aucune
  /// notion nouvelle, la distinction terminée/interrompue existe depuis
  /// l'étape 4.2.
  void abandon() {
    if (_state.status != SessionStatus.inProgress) return;
    _interruptSession();
  }

  SessionResult get result =>
      SessionResult(outcomes: _state.outcomes, totalScore: _state.score, scorer: scorer);

  void restart() {
    _timeoutTimer?.cancel();
    _state = SessionState.initial();
    _questionStartedAt = null;
    _lastLevelUpdates = null;
    _persistenceFailed = false;
    _failedWrite = null;
    _isRetryingPersistence = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
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
      // Peuplé même vide (échec ci-dessus, ou aucun type n'a atteint n_min
      // cette session) : `null` signifie spécifiquement « jamais calculé »
      // (session interrompue), pas « calculé, rien n'a changé ».
      _lastLevelUpdates = levelUpdates;
      _notifyIfAlive();
    }

    // Cache complet (7 types) après cette session, pas seulement les types
    // joués : voir `PersistedSession.overallLevelAfter`.
    double? overallLevelAfter;
    try {
      final cacheBefore = await repository.currentLevels(playerId);
      overallLevelAfter = overallLevel({...cacheBefore, ...levelUpdates});
    } on Exception catch (_) {
      // Un point en moins sur la courbe du Profil, rien de plus — ne bloque
      // pas l'écriture de la session elle-même.
    }

    final session = PersistedSession(
      id: sessionId,
      playerId: playerId,
      seed: config.seed,
      enabledTypes: config.enabledTypes,
      exerciseCount: config.exerciseCount,
      totalScore: _state.score,
      levels: config.levels,
      createdAt: createdAt,
      overallLevelAfter: overallLevelAfter,
    );

    await _record((session: session, answers: answers, levelUpdates: levelUpdates));
  }

  /// La persistance ne doit jamais casser la partie en cours : un échec est
  /// signalé ([persistenceFailed]) et l'écriture gardée pour
  /// [retryPersistence] — en mémoire seulement, perdue à la fermeture de
  /// l'app (la synchro serveur de la tranche 3 aura sa propre reprise).
  Future<void> _record(_SessionWrite write) async {
    try {
      await repository.recordSession(
        session: write.session,
        answers: write.answers,
        levelUpdates: write.levelUpdates,
      );
    } on Exception catch (_) {
      _failedWrite = write;
      _persistenceFailed = true;
      _notifyIfAlive();
      return;
    }
    if (_persistenceFailed) {
      _failedWrite = null;
      _persistenceFailed = false;
      _notifyIfAlive();
    }
  }
}
