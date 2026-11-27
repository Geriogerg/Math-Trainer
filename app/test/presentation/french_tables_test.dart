import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/account/account_exception.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_trainer/presentation/exercise_prompt.dart';
import 'package:math_trainer/presentation/strings/account_messages.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';
import 'package:math_trainer/presentation/strings/exercise_type_labels.dart';
import 'package:math_trainer/presentation/strings/method_labels.dart';
import 'package:math_trainer/presentation/strings/spoken_prompt.dart';
import 'package:math_trainer/presentation/strings/strings.dart';
import 'package:math_trainer/presentation/strings/tips.dart';
import 'package:math_trainer/presentation/strings/upload_refusal_text.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Phase 6d commit 3: the tables in French — operation and Method names,
/// messages, duel words, tips, what a screen reader says, and the numbers
/// of a percentage (the decimal comma, "de").
void main() {
  setUp(() => appLanguage.value = AppLanguage.french);
  tearDown(() => appLanguage.value = AppLanguage.english);

  test('a screen reader speaks French', () {
    expect(
      spokenPrompt(
        ArithmeticExercise(
          operandA: 47,
          operandB: 8,
          operationType: OperationType.multiplication,
        ),
      ),
      '47 fois 8',
    );
    expect(
      spokenPrompt(
        ArithmeticExercise(
          operandA: 96,
          operandB: 8,
          operationType: OperationType.division,
        ),
      ),
      '96 divisé par 8',
    );
    expect(spokenPrompt(PowerExercise(base: 12, exponent: 2)), '12 au carré');
    expect(
      spokenPrompt(SquareRootExercise(radicand: 27, index: 3)),
      'la racine cubique de 27',
    );
    expect(
      spokenPrompt(PercentageExercise(percent: 37, tenths: 5, base: 64)),
      '37,5 pour cent de 64',
    );
    expect(
      spokenPrompt(
        IntegralExercise(lower: 0, upper: 3, c0: 2, c1: 2, c2: 0, c3: 4),
      ),
      'l’intégrale de 0 à 3 de 4 x au cube plus 2 x plus 2, d x',
    );
  });

  test('names and messages', () {
    expect(exerciseTypeLabel(ExerciseType.squareRoot), 'Racines');
    expect(patternFamilyLabel(PatternFamily.times11), '× 10, plus lui-même');
    expect(duelModeLabel(DuelMode.count), 'Le compte est bon');
    expect(resultWord(1), 'Gagné');
    expect(
      describeAccountFailure(AccountFailure.invalidCredentials),
      'E-mail ou mot de passe incorrect.',
    );
    expect(uploadRefusalText('outOfOrder'), startsWith('Pas classée'));
    expect(
      unfinishedDuelsSentText([DuelMode.basics]),
      startsWith('Ton duel Bases inachevé'),
    );
    final tip = tips.firstWhere((t) => t.id == TipId.eighth);
    expect(tip.text, startsWith('12,5 %'));
    expect(tip.example, '37,5 % de 64 = 3 × 8 = 24');
  });

  testWidgets('a percentage prompt: "37,5 % de 64", in the digit face', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ExercisePrompt(
            exercise: PercentageExercise(percent: 37, tenths: 5, base: 64),
          ),
        ),
      ),
    );
    expect(find.text('37,5 % de 64'), findsOneWidget);
  });
}
