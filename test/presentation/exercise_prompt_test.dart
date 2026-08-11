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

  testWidgets('puissance affiche base^exposant (notation définitive au commit suivant)', (
    tester,
  ) async {
    await pump(tester, const PowerExercise(base: 3, exponent: 2));
    expect(find.text('3^2'), findsOneWidget);
  });

  testWidgets('racine carrée affiche √radicand (notation définitive au commit suivant)', (
    tester,
  ) async {
    await pump(tester, const SquareRootExercise(radicand: 16));
    expect(find.text('√16'), findsOneWidget);
  });
}
