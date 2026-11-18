import 'package:flutter/material.dart';

import '../core/domain/models/exercise.dart';
import '../core/domain/models/operation_type.dart';

/// Compose l'affichage d'un [Exercise] à partir des champs de sa variante —
/// le domaine ne produit plus de texte (`doc/decisions.md`, « Exercise.prompt
/// quitte le domaine »). `switch` exhaustif sans `default` (règle 11) :
/// tout nouveau type d'exercice fait échouer la compilation ici tant qu'il
/// n'a pas son rendu.
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
      PowerExercise e => _PowerPrompt(exercise: e, style: style),
      SquareRootExercise e => _SquareRootPrompt(exercise: e, style: style),
      PercentageExercise e => Text('${e.percent}% of ${e.base}', style: style),
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

/// Exposant en position haute, ~55 % de la taille de la base (`doc/design.md`)
/// — jamais `^`, jamais les chiffres Unicode `²`/`³` (rendent mal selon les
/// polices et s'arrêtent à 3). Le `WidgetSpan` aligné en haut de ligne donne
/// l'effet de décalage : un texte plus petit aligné sur le sommet de la ligne
/// se retrouve visuellement plus haut que la base.
class _PowerPrompt extends StatelessWidget {
  const _PowerPrompt({required this.exercise, required this.style});

  final PowerExercise exercise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final exponentStyle = style?.copyWith(fontSize: (style!.fontSize ?? 48) * 0.55);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '${exercise.base}'),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Text('${exercise.exponent}', style: exponentStyle),
          ),
        ],
      ),
    );
  }
}

/// Barre horizontale au-dessus du radicande (`doc/design.md`) : sans elle,
/// `√169` se lit `√1` puis `69`. `Border(top:)` sur le radicande seul — le
/// symbole `√` n'est pas sous la barre, simplification assumée par
/// `doc/design.md`.
class _SquareRootPrompt extends StatelessWidget {
  const _SquareRootPrompt({required this.exercise, required this.style});

  final SquareRootExercise exercise;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('√', style: style),
        Container(
          padding: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: style?.color ?? Theme.of(context).colorScheme.onSurface,
                width: 2,
              ),
            ),
          ),
          child: Text('${exercise.radicand}', style: style),
        ),
      ],
    );
  }
}
