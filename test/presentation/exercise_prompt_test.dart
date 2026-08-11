import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/core/domain/models/exercise.dart';
import 'package:math_trainer/core/domain/models/operation_type.dart';
import 'package:math_trainer/presentation/exercise_prompt.dart';

void main() {
  Future<void> pump(WidgetTester tester, Exercise exercise) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: ExercisePrompt(exercise: exercise))),
  );

  testWidgets('addition affiche a + b', (tester) async {
    await pump(
      tester,
      const ArithmeticExercise(operandA: 4, operandB: 3, operationType: OperationType.addition),
    );
    expect(find.text('4 + 3'), findsOneWidget);
  });

  testWidgets('soustraction affiche le vrai signe moins (U+2212), pas un trait d\'union', (
    tester,
  ) async {
    await pump(
      tester,
      const ArithmeticExercise(
        operandA: 9,
        operandB: 2,
        operationType: OperationType.subtraction,
      ),
    );
    expect(find.text('9 − 2'), findsOneWidget);
    expect(find.text('9 - 2'), findsNothing);
  });

  testWidgets('multiplication affiche ×', (tester) async {
    await pump(
      tester,
      const ArithmeticExercise(
        operandA: 6,
        operandB: 7,
        operationType: OperationType.multiplication,
      ),
    );
    expect(find.text('6 × 7'), findsOneWidget);
  });

  testWidgets('division affiche ÷', (tester) async {
    await pump(
      tester,
      const ArithmeticExercise(operandA: 8, operandB: 4, operationType: OperationType.division),
    );
    expect(find.text('8 ÷ 4'), findsOneWidget);
  });

  testWidgets('pourcentage affiche « p% de a »', (tester) async {
    await pump(tester, const PercentageExercise(percent: 25, base: 80));
    expect(find.text('25% de 80'), findsOneWidget);
  });

  testWidgets('puissance affiche la base et l\'exposant, jamais un accent circonflexe', (
    tester,
  ) async {
    await pump(tester, const PowerExercise(base: 3, exponent: 2));

    // La base vit dans le TextSpan d'un Text.rich (pas un Text.data séparé) :
    // on vérifie son contenu textuel plutôt que sa présence via find.text.
    final richText = tester.widget<Text>(
      find.byWidgetPredicate((widget) => widget is Text && widget.textSpan != null),
    );
    expect(richText.textSpan!.toPlainText(includePlaceholders: false), '3');

    // L'exposant est un Text indépendant (dans un WidgetSpan) : find.text le
    // trouve directement, et on vérifie qu'il est bien plus petit que la base.
    final exponentFinder = find.text('2');
    expect(exponentFinder, findsOneWidget);
    final baseSize = richText.textSpan!.style!.fontSize!;
    final exponentSize = tester.widget<Text>(exponentFinder).style!.fontSize!;
    expect(exponentSize, closeTo(baseSize * 0.55, 0.01));

    expect(find.textContaining('^'), findsNothing);
  });

  testWidgets('racine carrée affiche une barre au-dessus du radicande', (tester) async {
    await pump(tester, const SquareRootExercise(radicand: 16));

    expect(find.text('√'), findsOneWidget);
    final radicandFinder = find.text('16');
    expect(radicandFinder, findsOneWidget);

    final container = tester.widget<Container>(
      find.ancestor(of: radicandFinder, matching: find.byType(Container)),
    );
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNotNull);
  });
}
