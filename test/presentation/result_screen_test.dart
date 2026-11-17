import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/generation/exercise_source.dart';
import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/core/domain/models/session_config.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/core/state/session_controller.dart';
import 'package:math_trainer/presentation/screens/result_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Même double que les autres tests de contrôleur/golden — pas
/// d'infrastructure de test partagée pour une seule classe de quelques
/// lignes (convention du projet).
class _FixedExerciseSource implements ExerciseSource {
  _FixedExerciseSource(this._exercises);

  final List<Exercise> _exercises;
  int _index = 0;

  @override
  Exercise next() => _exercises[_index++];
}

class _RecordFailureRepository extends InMemorySessionRepository {
  /// Repasser à `false` simule un stockage revenu.
  bool failing = true;

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) async {
    if (failing) throw Exception('stockage indisponible (simulé)');
    await super.recordSession(session: session, answers: answers, levelUpdates: levelUpdates);
  }
}

void main() {
  List<Exercise> additionExercises(int count) => List.generate(
    count,
    (i) => ArithmeticExercise(operandA: i, operandB: 0, operationType: OperationType.addition),
  );

  SessionController finishedController({SessionRepository? repository}) {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        levels: const {ExerciseType.addition: 50},
      ),
      exerciseSource: _FixedExerciseSource(additionExercises(4)),
      repository: repository ?? InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      createTimer: (duration, callback) => _InertTimer(),
    );
    controller.start();
    for (var i = 0; i < 4; i++) {
      controller.submitAnswer(i); // toujours correct
    }
    return controller;
  }

  Future<void> pumpResultScreen(
    WidgetTester tester,
    SessionController controller, {
    VoidCallback? onPlayAgain,
    VoidCallback? onExitToSelection,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ResultScreen(
            controller: controller,
            onPlayAgain: onPlayAgain ?? () {},
            onExitToSelection: onExitToSelection ?? () {},
            isRestarting: false,
            restartError: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('session terminée : changement de niveau, score décomposé, décompte, meta', (
    tester,
  ) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Addition — niveau'), findsOneWidget);
    expect(find.textContaining('Score : '), findsOneWidget);
    expect(find.textContaining('Base : '), findsOneWidget);
    expect(find.textContaining('Bonus de vitesse : '), findsOneWidget);
    expect(find.textContaining('Bonus de série : '), findsOneWidget);
    expect(find.textContaining('Bonus de difficulté : '), findsOneWidget);
    expect(find.textContaining('4 justes · 0 fausses · 0 hors délai'), findsOneWidget);
    expect(find.textContaining('Temps moyen : '), findsOneWidget);
    expect(find.textContaining('Meilleure série : 4'), findsOneWidget);
    expect(find.textContaining('Types joués : Addition'), findsOneWidget);
    // Jamais de pourcentage présenté comme un progrès (`doc/design.md`).
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets(
    'Bonus de difficulté absent quand il vaut 0 (niveau 1, aucun multiplicateur)',
    (tester) async {
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition},
          exerciseCount: 4,
          levels: const {ExerciseType.addition: 1},
        ),
        exerciseSource: _FixedExerciseSource(additionExercises(4)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _InertTimer(),
      );
      addTearDown(controller.dispose);
      controller.start();
      for (var i = 0; i < 4; i++) {
        controller.submitAnswer(i);
      }
      await controller.pendingPersistence;

      await pumpResultScreen(tester, controller);

      expect(find.textContaining('Bonus de difficulté'), findsNothing);
    },
  );

  testWidgets(
    'un type resté sous n_min cette session est distingué d\'un niveau inchangé',
    (tester) async {
      // Deux types activés, mais la source d'exercices ne produit que de
      // l'addition : la soustraction reste à 0 réponse, donc sous n_min —
      // computeUpdates ne lui crée aucune entrée (voir level_cache_orchestrator.dart).
      final controller = SessionController(
        config: SessionConfig(
          seed: 1,
          enabledTypes: const {ExerciseType.addition, ExerciseType.subtraction},
          exerciseCount: 4,
          levels: const {ExerciseType.addition: 50, ExerciseType.subtraction: 50},
        ),
        exerciseSource: _FixedExerciseSource(additionExercises(4)),
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        clock: () => DateTime(2024),
        createTimer: (duration, callback) => _InertTimer(),
      );
      addTearDown(controller.dispose);
      controller.start();
      for (var i = 0; i < 4; i++) {
        controller.submitAnswer(i);
      }
      await controller.pendingPersistence;

      await pumpResultScreen(tester, controller);

      expect(
        find.text('Soustraction — niveau 50 (pas assez de réponses pour compter)'),
        findsOneWidget,
      );
      // L'addition, elle, a bien été évaluée : pas ce texte-là pour elle.
      expect(find.textContaining('Addition — niveau 50 (pas assez'), findsNothing);
    },
  );

  testWidgets('session interrompue : pas de bloc de changement de niveau', (tester) async {
    final controller = SessionController(
      config: SessionConfig(
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 4,
        levels: const {ExerciseType.addition: 50},
      ),
      exerciseSource: _FixedExerciseSource(additionExercises(4)),
      repository: InMemorySessionRepository(),
      playerId: 'test-player',
      clock: () => DateTime(2024),
      createTimer: (duration, callback) => _InertTimer(),
    );
    addTearDown(controller.dispose);
    controller.start();
    controller.submitAnswer(0);
    controller.abandon();
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.text('Session interrompue'), findsOneWidget);
    expect(find.textContaining('Addition — niveau'), findsNothing);
  });

  testWidgets('Rejouer et Nouvelle sélection déclenchent leurs callbacks respectifs', (
    tester,
  ) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    var playAgainTapped = false;
    var exitTapped = false;
    await pumpResultScreen(
      tester,
      controller,
      onPlayAgain: () => playAgainTapped = true,
      onExitToSelection: () => exitTapped = true,
    );

    await tester.tap(find.text('Rejouer'));
    expect(playAgainTapped, isTrue);

    await tester.tap(find.text('Nouvelle sélection'));
    expect(exitTapped, isTrue);
  });

  testWidgets('enregistrement raté : la partie est signalée comme non comptée', (
    tester,
  ) async {
    final controller = finishedController(
      repository: _RecordFailureRepository(),
    );
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Partie non enregistrée'), findsOneWidget);
  });

  testWidgets('enregistrement réussi : aucun avertissement', (tester) async {
    final controller = finishedController();
    addTearDown(controller.dispose);
    await controller.pendingPersistence;

    await pumpResultScreen(tester, controller);

    expect(find.textContaining('Partie non enregistrée'), findsNothing);
    expect(find.text("Réessayer l'enregistrement"), findsNothing);
  });

  testWidgets("« Réessayer l'enregistrement » enregistre la partie et retire l'avertissement", (
    tester,
  ) async {
    final repository = _RecordFailureRepository();
    final controller = finishedController(repository: repository);
    addTearDown(controller.dispose);
    await controller.pendingPersistence;
    // Comme `SessionFlowScreen` : c'est son `ListenableBuilder` qui
    // reconstruit l'écran de résultat quand le contrôleur notifie.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => ResultScreen(
              controller: controller,
              onPlayAgain: () {},
              onExitToSelection: () {},
              isRestarting: false,
              restartError: null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.failing = false;
    await tester.tap(find.text("Réessayer l'enregistrement"));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Partie non enregistrée'), findsNothing);
    expect(find.text("Réessayer l'enregistrement"), findsNothing);
    expect(await repository.recentSessions('test-player'), hasLength(1));
  });
}

class _InertTimer implements Timer {
  @override
  void cancel() {}

  @override
  bool get isActive => false;

  @override
  int get tick => 0;
}
