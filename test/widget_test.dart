import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/app.dart';

void main() {
  testWidgets('affiche l\'écran d\'accueil', (WidgetTester tester) async {
    await tester.pumpWidget(const MathTrainerApp());

    expect(find.text('Math Trainer'), findsOneWidget);
  });

  testWidgets('démarrer une session affiche une question et un champ de saisie', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MathTrainerApp());

    await tester.tap(find.text('Commencer'));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Valider'), findsOneWidget);
    expect(find.text('Math Trainer'), findsNothing);
  });
}
