import 'dart:async';

import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/core/state/session_state.dart';
import 'package:test/test.dart';

class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

/// Timer factice : ne se déclenche jamais tout seul (pas de vraie horloge),
/// seulement quand le test appelle [fire] explicitement. Le défaut de
/// [buildController] en construit un par question sans jamais appeler
/// [fire] — inerte, donc aucun timer réel ne reste en attente à la fin d'un
/// test qui ne teste pas le timeout lui-même.
class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  bool _cancelled = false;
  bool _fired = false;

  void fire() {
    if (_cancelled || _fired) return;
    _fired = true;
    _callback();
  }

  @override
  void cancel() => _cancelled = true;

  @override
  bool get isActive => !_cancelled && !_fired;

  @override
  int get tick => 0;
}

/// Capture chaque `_FakeTimer` créé par `SessionController` (un par
/// question armée), dans l'ordre — `latest` est celui de la question
/// actuellement affichée.
class _TimerSpy {
  final List<_FakeTimer> created = [];

  Timer create(Duration duration, void Function() callback) {
    final timer = _FakeTimer(callback);
    created.add(timer);
    return timer;
  }

  _FakeTimer get latest => created.last;
}

/// `currentLevels` échoue (simule une lecture de cache ratée), mais
/// `recordSession` délègue à un `InMemorySessionRepository` interne
/// fonctionnel — pour vérifier que la session et ses réponses sont bien
/// enregistrées malgré l'échec de lecture du cache.
class _LevelReadFailureRepository implements SessionRepository {
  final inner = InMemorySessionRepository();

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw Exception('échec simulé de lecture du cache');

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => inner.recordSession(session: session, answers: answers, levelUpdates: levelUpdates);

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) =>
      inner.recentSessions(limit: limit);

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      inner.answersForSession(sessionId);
}

/// `currentLevels` lève un `Error` (pas une `Exception`) : simule un bug —
/// un invariant qui casse quelque part dans la chaîne — plutôt qu'un échec
/// d'E/S attendu.
class _BuggyLevelReadRepository implements SessionRepository {
  final inner = InMemorySessionRepository();

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw ArgumentError('bug simulé, pas un échec réseau/disque');

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => inner.recordSession(session: session, answers: answers, levelUpdates: levelUpdates);

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) =>
      inner.recentSessions(limit: limit);

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      inner.answersForSession(sessionId);
}

void main() {
  const exercises = [
    ArithmeticExercise(operandA: 2, operandB: 2, operationType: OperationType.addition),
    ArithmeticExercise(operandA: 5, operandB: 3, operationType: OperationType.addition),
    ArithmeticExercise(operandA: 9, operandB: 1, operationType: OperationType.addition),
  ];

  SessionController buildController({InMemorySessionRepository? repository}) {
    return SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: {ExerciseType.addition},
        exerciseCount: exercises.length,
        levels: {ExerciseType.addition: 1},
      ),
      exerciseSource: _FixedExerciseSource(exercises),
      repository: repository ?? InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      // Inerte par défaut : ces tests ne portent pas sur le timeout, un vrai
      // Timer(Duration(seconds: 15), ...) resterait en attente à la fin du
      // test.
      createTimer: (duration, callback) => _FakeTimer(callback),
    );
  }

  group('SessionController', () {
    test('start() passe en cours et affiche le premier exercice', () {
      final controller = buildController();

      controller.start();

      expect(controller.state.status, SessionStatus.inProgress);
      expect(controller.state.currentExercise, exercises[0]);
      expect(controller.state.score, 0);
    });

    test('submitAnswer ignoré avant start()', () {
      final controller = buildController();

      controller.submitAnswer(4);

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.outcomes, isEmpty);
    });

    test('enchaîne les exercices et calcule score/streak/résultat final', () {
      final controller = buildController();
      controller.start();

      controller.submitAnswer(4); // correct, exercises[0] : 2+2
      expect(controller.state.currentStreak, 1);
      expect(controller.state.score, 20); // base 10 + bonus vitesse max 10 (élapsé nul)
      expect(controller.state.currentExercise, exercises[1]);

      controller.submitAnswer(0); // incorrect, exercises[1] : 5+3=8
      expect(controller.state.currentStreak, 0);
      expect(controller.state.score, 20);
      expect(controller.state.currentExercise, exercises[2]);

      controller.submitAnswer(10); // correct, exercises[2] : 9+1
      expect(controller.state.status, SessionStatus.finished);
      expect(controller.state.currentExercise, isNull);

      final result = controller.result;
      expect(result.correctCount, 2);
      expect(result.outcomes.length, 3);
      expect(result.totalScore, controller.state.score);
    });

    test('le score est pondéré par le niveau figé de l\'opération', () {
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: exercises.length,
          levels: {ExerciseType.addition: 100},
        ),
        exerciseSource: _FixedExerciseSource(exercises),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
      );
      controller.start();

      controller.submitAnswer(4); // correct, exercises[0] : 2+2

      // base 10 + bonus vitesse max 10 = 20 bruts ; niveau 100, bonusMax par
      // défaut 1.0 → multiplicateur 2 → 40.
      expect(controller.state.score, 40);
    });

    test('persiste la session dans le repository une fois terminée', () async {
      final repository = InMemorySessionRepository();
      final controller = buildController(repository: repository);
      controller.start();

      controller.submitAnswer(4);
      controller.submitAnswer(0);
      controller.submitAnswer(10);

      // Laisse la persistance asynchrone (non attendue par submitAnswer) se
      // dérouler avant de vérifier le repository.
      await Future<void>.delayed(Duration.zero);

      final sessions = await repository.recentSessions();
      expect(sessions, hasLength(1));
      expect(sessions.single.playerId, 'test-player');
      expect(sessions.single.totalScore, controller.state.score);
      expect(sessions.single.levels, {ExerciseType.addition: 1});

      final answers = await repository.answersForSession(sessions.single.id);
      expect(answers, hasLength(3));
      expect(answers.map((a) => a.isCorrect), [true, false, true]);

      // 3 réponses < n_min (4, étape 4.2) : le cache de niveau n'est pas touché.
      expect(await repository.currentLevels('test-player'), isEmpty);
    });

    test('une session avec au moins n_min réponses justes et rapides met à jour le cache de '
        'niveau (calibration, première fois sur cette opération)', () async {
      final repository = InMemorySessionRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: 50},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      for (var i = 0; i < 8; i++) {
        controller.submitAnswer(i); // i + 0 = i : toujours correct
      }
      await Future<void>.delayed(Duration.zero);

      final levels = await repository.currentLevels('test-player');
      // Depuis niveau 50, 8 réponses justes et instantanées (n_min = 4,
      // pondération √(8/4) — voir doc/decisions.md), confiance « calibration »
      // (première session sur cette opération) : le changement non clampé
      // dépasse deltaMax, borné à 3 → 53.
      expect(levels[ExerciseType.addition]?.level, 53);
      expect(levels[ExerciseType.addition]?.sessionsPlayed, 1);
    });

    test('une lecture ratée du cache de niveaux n\'empêche pas la session d\'être '
        'enregistrée', () async {
      final repository = _LevelReadFailureRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: 50},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      controller.start();
      for (var i = 0; i < 8; i++) {
        controller.submitAnswer(i);
      }
      await Future<void>.delayed(Duration.zero);

      // La session et ses réponses (non reconstructibles) sont là malgré
      // l'échec de lecture du cache.
      final sessions = await repository.inner.recentSessions();
      expect(sessions, hasLength(1));
      final answers = await repository.inner.answersForSession(sessions.single.id);
      expect(answers, hasLength(8));

      // Le cache de niveaux (recalculable), lui, n'a pas pu être mis à jour
      // cette fois — pas d'entrée, mais pas de session perdue non plus.
      expect(await repository.inner.currentLevels('test-player'), isEmpty);
    });

    test('un Error (bug) lors du calcul du cache n\'est pas avalé silencieusement', () async {
      final repository = _BuggyLevelReadRepository();
      final eightExercises = List.generate(
        8,
        (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
      );
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: 8,
          levels: {ExerciseType.addition: 50},
        ),
        exerciseSource: _FixedExerciseSource(eightExercises),
        repository: repository,
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _FakeTimer(callback),
      );

      final uncaughtErrors = <Object>[];
      await runZonedGuarded(() async {
        controller.start();
        for (var i = 0; i < 8; i++) {
          controller.submitAnswer(i);
        }
        // _persistCompletedSession est déclenché en tâche de fond
        // (unawaited) : laisse l'erreur non gérée remonter à la zone avant
        // de vérifier.
        await Future<void>.delayed(Duration.zero);
      }, (error, stack) => uncaughtErrors.add(error));

      expect(uncaughtErrors, hasLength(1));
      expect(uncaughtErrors.single, isA<ArgumentError>());

      // L'Error propage avant d'atteindre recordSession (règle 13 : ne pas
      // continuer après un invariant cassé) — contrairement au cas d'une
      // Exception (test précédent), où recordSession s'exécute quand même.
      final sessions = await repository.inner.recentSessions();
      expect(sessions, isEmpty);
    });

    test('restart() réinitialise complètement la session', () {
      final controller = buildController();
      controller.start();
      controller.submitAnswer(4);

      controller.restart();

      expect(controller.state.status, SessionStatus.notStarted);
      expect(controller.state.score, 0);
      expect(controller.state.outcomes, isEmpty);
      expect(controller.state.currentExercise, isNull);
    });
  });

  group('Timeout par question (étape 4.2, commit B)', () {
    List<ArithmeticExercise> manyExercises(int count) => List.generate(
      count,
      (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
    );

    SessionController buildTimeoutController({
      required _TimerSpy spy,
      required int exerciseCount,
      SessionRepository? repository,
    }) {
      return SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: {ExerciseType.addition},
          exerciseCount: exerciseCount,
          levels: {ExerciseType.addition: 50},
        ),
        exerciseSource: _FixedExerciseSource(manyExercises(exerciseCount)),
        repository: repository ?? InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: spy.create,
      );
    }

    test('un timeout sans activité compte comme faux et avance à la question suivante', () {
      final spy = _TimerSpy();
      final controller = buildTimeoutController(spy: spy, exerciseCount: 5);

      controller.start();
      spy.latest.fire();

      expect(controller.state.status, SessionStatus.inProgress);
      expect(controller.state.outcomes, hasLength(1));
      expect(controller.state.outcomes.single.isCorrect, isFalse);
      expect(controller.state.outcomes.single.isTimeout, isTrue);
      expect(controller.state.currentExercise, manyExercises(5)[1]);
    });

    test(
      'un timeout après une activité (saisie jamais validée) ne compte pas pour l\'abandon',
      () {
        final spy = _TimerSpy();
        final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

        controller.start();
        // 3 timeouts, mais avec une activité à chaque fois : ne doit jamais
        // interrompre.
        for (var i = 0; i < 3; i++) {
          controller.registerActivity();
          spy.latest.fire();
        }

        expect(controller.state.status, SessionStatus.inProgress);
        expect(controller.state.outcomes, hasLength(3));
      },
    );

    test('trois timeouts consécutifs sans aucune activité interrompent la session', () {
      final spy = _TimerSpy();
      final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

      controller.start();
      spy.latest.fire();
      spy.latest.fire();
      spy.latest.fire();

      expect(controller.state.status, SessionStatus.interrupted);
      expect(controller.state.outcomes, hasLength(3));
      expect(controller.state.currentExercise, isNull);
    });

    test('une vraie réponse entre deux timeouts remet le compteur d\'abandon à zéro', () {
      final spy = _TimerSpy();
      final controller = buildTimeoutController(spy: spy, exerciseCount: 10);

      controller.start();
      spy.latest.fire(); // timeout 1, pas d'activité
      spy.latest.fire(); // timeout 2, pas d'activité
      controller.submitAnswer(0); // réponse réelle : remet le compteur à 0
      spy.latest.fire(); // timeout 1 (nouveau compte)
      spy.latest.fire(); // timeout 2

      // 4 timeouts + 1 vraie réponse, mais jamais 3 timeouts consécutifs sans
      // activité : toujours en cours.
      expect(controller.state.status, SessionStatus.inProgress);
    });

    test(
      'une session interrompue enregistre les réponses déjà données mais pas le niveau',
      () async {
        final repository = InMemorySessionRepository();
        final spy = _TimerSpy();
        final controller = buildTimeoutController(
          spy: spy,
          exerciseCount: 10,
          repository: repository,
        );

        controller.start();
        spy.latest.fire();
        spy.latest.fire();
        spy.latest.fire();
        await Future<void>.delayed(Duration.zero);

        final sessions = await repository.recentSessions();
        expect(sessions, hasLength(1));
        // exerciseCount reste le compte prévu (10), pas le nombre de réponses
        // réellement données (3) : c'est cet écart qui distingue une session
        // interrompue d'une session terminée, sans champ dédié.
        expect(sessions.single.exerciseCount, 10);
        final answers = await repository.answersForSession(sessions.single.id);
        expect(answers, hasLength(3));

        // Pas comptabilisée pour les niveaux.
        expect(await repository.currentLevels('test-player'), isEmpty);
      },
    );

    test('restart() annule le timer de la session en cours', () {
      final spy = _TimerSpy();
      final controller = buildTimeoutController(spy: spy, exerciseCount: 5);

      controller.start();
      final staleTimer = spy.latest;
      expect(staleTimer.isActive, isTrue);

      controller.restart();

      expect(staleTimer.isActive, isFalse);
      expect(controller.state.status, SessionStatus.notStarted);
    });
  });
}
