import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_trainer/presentation/exercise_prompt.dart';

void main() {
  Future<void> pump(WidgetTester tester, Exercise exercise) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ExercisePrompt(exercise: exercise)),
        ),
      );

  testWidgets('addition shows a + b', (tester) async {
    await pump(
      tester,
      const ArithmeticExercise(
        operandA: 4,
        operandB: 3,
        operationType: OperationType.addition,
      ),
    );
    expect(find.text('4 + 3'), findsOneWidget);
  });

  testWidgets('subtraction shows the true minus sign (U+2212), not a hyphen', (
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

  testWidgets('multiplication shows ×', (tester) async {
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

  testWidgets('division shows ÷', (tester) async {
    await pump(
      tester,
      const ArithmeticExercise(
        operandA: 8,
        operandB: 4,
        operationType: OperationType.division,
      ),
    );
    expect(find.text('8 ÷ 4'), findsOneWidget);
  });

  testWidgets('percentage shows "p% of a"', (tester) async {
    await pump(tester, const PercentageExercise(percent: 25, base: 80));
    expect(find.text('25% of 80'), findsOneWidget);
  });

  testWidgets('power shows the base and the exponent, never a caret', (
    tester,
  ) async {
    await pump(tester, const PowerExercise(base: 3, exponent: 2));

    // The base lives in the TextSpan of a Text.rich (not a separate Text.data):
    // check its text content rather than its presence through find.text.
    final richText = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan != null,
      ),
    );
    expect(richText.textSpan!.toPlainText(includePlaceholders: false), '3');

    // The exponent is a separate Text (in a WidgetSpan): find.text finds it
    // directly, and we check it is indeed smaller than the base.
    final exponentFinder = find.text('2');
    expect(exponentFinder, findsOneWidget);
    final baseSize = richText.textSpan!.style!.fontSize!;
    final exponentSize = tester.widget<Text>(exponentFinder).style!.fontSize!;
    expect(exponentSize, closeTo(baseSize * 0.55, 0.01));

    expect(find.textContaining('^'), findsNothing);
  });

  testWidgets('square root shows a bar over the radicand', (tester) async {
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

  group('integral', () {
    test('terms: highest power first, no zero term', () {
      final e = IntegralExercise(
        lower: 0,
        upper: 2,
        c0: 2,
        c1: 0,
        c2: 3,
        c3: 4,
      );
      expect(integralTerms(e), [
        (coefficient: '4', power: 3),
        (coefficient: '3', power: 2),
        (coefficient: '2', power: 0),
      ]);
    });

    testWidgets('∫ with its bounds, the polynomial and dx', (tester) async {
      await pump(
        tester,
        IntegralExercise(lower: 0, upper: 3, c0: 0, c1: 2, c2: 0, c3: 0),
      );
      expect(find.text('∫'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.textContaining('2x'), findsOneWidget);
      expect(find.textContaining('dx'), findsOneWidget);
    });
  });
}
