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
}
