import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/presentation/screens/session_screen.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';

class _ThrowingSessionRepository implements SessionRepository {
  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw Exception('échec simulé');

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) =>
      throw Exception('échec simulé');

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw Exception('échec simulé');

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) =>
      throw Exception('échec simulé');

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      throw Exception('échec simulé');

  @override
  Future<List<PersistedSession>> sessionsSince(String playerId, DateTime since) =>
      throw Exception('échec simulé');
}

void main() {
  final testEnvironment = AppEnvironment(
    repository: InMemorySessionRepository(),
    playerId: 'test-player',
  );

  // Fait avancer le temps juste assez pour que la transition standard de
  // MaterialPageRoute se stabilise, sans attendre le reste (le chrono de
  // SessionScreen tourne 5 s à chaque question : un pumpAndSettle() ici
  // n'arriverait jamais à convergence tant qu'une nouvelle question relance
  // l'animation).
  Future<void> settlePageTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('affiche l\'écran d\'accueil', (WidgetTester tester) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('démarrer une session pousse le pavé numérique en plein écran', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Commencer'));
    await settlePageTransition(tester);

    expect(find.text('7'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
  });

  testWidgets('aucun type sélectionné désactive Commencer et explique pourquoi', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    // Décoche les 2 types pré-sélectionnés par défaut (étape 4.1, commit A).
    for (final label in ['Addition', 'Soustraction']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }

    expect(find.text('Aucun type sélectionné.'), findsOneWidget);

    await tester.tap(find.text('Commencer'));
    await tester.pump();

    // Toujours sur l'écran de sélection : le bouton désactivé n'a rien déclenché.
    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('un seul type sélectionné démarre une session mono-type', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Soustraction'));
    await tester.pump();
    await tester.tap(find.text('Commencer'));
    await settlePageTransition(tester);

    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets(
    'le geste retour pendant une session demande confirmation avant d\'interrompre (étape 5, commit A)',
    (WidgetTester tester) async {
      await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

      await tester.tap(find.text('Commencer'));
      await settlePageTransition(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Pas de bouton retour visible (`doc/design.md` : l'écran de session ne
      // porte aucune navigation) : on déclenche la tentative de pop comme le
      // ferait le geste système, via le Navigator qui porte la route poussée.
      // `pumpAndSettle()` est proscrit ici (voir `settlePageTransition`) : le
      // chrono de la question tourne toujours pendant que le dialogue est
      // ouvert, et ferait avancer le temps virtuel jusqu'au timeout.
      Future<void> attemptPop() async {
        final context = tester.element(find.byType(SessionScreen));
        Navigator.of(context).maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
      }

      await attemptPop();
      expect(find.text('Quitter la partie ?'), findsOneWidget);

      // Annuler : le dialogue se ferme, la session continue sans rien perdre.
      await tester.tap(find.text('Annuler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Quitter la partie ?'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // Nouvelle tentative, confirmée cette fois : la session est interrompue.
      await attemptPop();
      await tester.tap(find.text('Quitter'));
      await settlePageTransition(tester);

      expect(find.text('Session interrompue'), findsOneWidget);
    },
  );

  /// 2 types par défaut, n_min=4 (étape 4.2) : sessionLengthFor(2, 4, 24) = 8
  /// questions. La borne de boucle (20) reste une marge de sécurité, pas le
  /// compte réel. Taper '1' puis valider, sans pump entre les deux pour
  /// éviter toute collision avec le '1' qui apparaîtrait ensuite dans la
  /// réponse affichée.
  Future<void> playToCompletion(WidgetTester tester) async {
    for (var i = 0; i < 20 && find.text('Session terminée').evaluate().isEmpty; i++) {
      await tester.tap(find.text('1'));
      await tester.tap(find.byIcon(Icons.check));
      await tester.pump();
    }
    expect(find.text('Session terminée'), findsOneWidget);
  }

  testWidgets('« Nouvelle sélection » après une session ramène à l\'écran de sélection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Commencer'));
    await settlePageTransition(tester);
    await playToCompletion(tester);

    await tester.tap(find.text('Nouvelle sélection'));
    await settlePageTransition(tester);

    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
  });

  testWidgets('« Rejouer » relance immédiatement sans repasser par la sélection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Commencer'));
    await settlePageTransition(tester);
    await playToCompletion(tester);

    await tester.tap(find.text('Rejouer'));
    await settlePageTransition(tester);

    // Directement de retour sur le pavé, pas sur l'écran de sélection : « 1 »
    // est la nouvelle première question, jamais l'écran « Math Trainer ».
    expect(find.text('Math Trainer'), findsNothing);
    expect(find.text('1 / 8'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('la barre d\'onglets bascule vers Progression sans perdre la sélection de Jouer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Multiplication'));
    await tester.pump();

    await tester.tap(find.text('Progression'));
    await tester.pumpAndSettle();
    expect(find.text('Addition'), findsOneWidget);
    expect(find.text('Non joué'), findsWidgets);

    await tester.tap(find.text('Jouer'));
    await tester.pumpAndSettle();

    // IndexedStack : l'onglet Jouer garde son état, Multiplication reste coché.
    final chip = tester.widget<FilterChip>(
      find.ancestor(of: find.text('Multiplication'), matching: find.byType(FilterChip)),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('un repository qui échoue au démarrage affiche un message et laisse réessayer', (
    WidgetTester tester,
  ) async {
    final failingEnvironment = AppEnvironment(
      repository: _ThrowingSessionRepository(),
      playerId: 'test-player',
    );
    await tester.pumpWidget(MathTrainerApp(environment: failingEnvironment));

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de démarrer la session.'), findsOneWidget);
    // Le bouton est redevenu actif : c'est l'action de reprise.
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);

    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();

    // Toujours bloqué (même repository), toujours le même message, pas de crash.
    expect(find.text('Impossible de démarrer la session.'), findsOneWidget);
  });
}
