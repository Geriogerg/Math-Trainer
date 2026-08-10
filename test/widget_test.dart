import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/app.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';

void main() {
  final testEnvironment = AppEnvironment(
    repository: InMemorySessionRepository(),
    playerId: 'test-player',
  );

  testWidgets('affiche l\'écran d\'accueil', (WidgetTester tester) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('démarrer une session affiche une question et un champ de saisie', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Commencer'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(find.text('Math Trainer'), findsNothing);
  });

  testWidgets('aucun type sélectionné désactive Commencer', (WidgetTester tester) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    // Décoche les 2 types pré-sélectionnés par défaut (étape 4.1, commit A).
    for (final label in ['Addition', 'Soustraction']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pump();

    // Toujours sur l'écran de sélection : le bouton désactivé n'a rien déclenché.
    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('un seul type sélectionné démarre une session mono-type', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Soustraction'));
    await tester.pump();
    await tester.tap(find.text('Commencer'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('recommencer après une session ramène à l\'écran de sélection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Commencer'));
    await tester.pump();

    // 2 types par défaut, n_min=8 : sessionLengthFor(2, 8, 24) = 16
    // questions (étape 4.1, commit A) — pas 10.
    for (var i = 0; i < 20 && find.text('Session terminée').evaluate().isEmpty; i++) {
      await tester.enterText(find.byType(TextField), '1');
      await tester.tap(find.text('Valider'));
      await tester.pump();
    }
    expect(find.text('Session terminée'), findsOneWidget);

    await tester.tap(find.text('Recommencer'));
    await tester.pump();

    expect(find.text('Math Trainer'), findsOneWidget);
    expect(find.byType(FilterChip), findsWidgets);
  });

  testWidgets('« Voir ma progression » ouvre l\'écran de progression puis y revient', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MathTrainerApp(environment: testEnvironment));

    await tester.tap(find.text('Voir ma progression'));
    await tester.pumpAndSettle();

    expect(find.text('Progression'), findsOneWidget);
    expect(find.text('Addition'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Math Trainer'), findsOneWidget);
  });
}
