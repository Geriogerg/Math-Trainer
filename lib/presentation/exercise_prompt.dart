import 'package:flutter/material.dart';

import '../core/domain/models/exercise.dart';
import '../core/domain/models/operation_type.dart';

/// Compose l'affichage d'un [Exercise] à partir des champs de sa variante —
/// le domaine ne produit plus de texte (`doc/decisions.md`, « Exercise.prompt
/// quitte le domaine »). `switch` exhaustif sans `default` (règle 11) :
/// tout nouveau type d'exercice fait échouer la compilation ici tant qu'il
/// n'a pas son rendu.
///
/// Puissance et racine carrée n'ont pas encore leur notation définitive
/// (exposant en position haute, barre sur le radicande — `doc/design.md`) :
/// ce rendu arrive au commit suivant, qui touchera uniquement ces deux
/// branches.
class ExercisePrompt extends StatelessWidget {
  const ExercisePrompt({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displayMedium;
    return switch (exercise) {
      ArithmeticExercise e => Text(
        '${e.operandA} ${_operatorSymbol(e.operationType)} ${e.operandB}',
        style: style,
      ),
      PowerExercise e => Text('${e.base}^${e.exponent}', style: style),
      SquareRootExercise e => Text('√${e.radicand}', style: style),
      PercentageExercise e => Text('${e.percent}% de ${e.base}', style: style),
    };
  }
}

String _operatorSymbol(OperationType type) => switch (type) {
  OperationType.addition => '+',
  // Vrai signe moins U+2212, jamais le trait d'union U+002D (`doc/design.md`).
  OperationType.subtraction => '−',
  OperationType.multiplication => '×',
  OperationType.division => '÷',
};
