import 'package:flutter/material.dart';

/// Remplace un `SizedBox.shrink()` comme état d'écran (`doc/design.md`) : un
/// écran vide est une impasse, message et action de sortie obligatoires.
/// Partagé entre `SessionScreen` et `SessionFlowScreen` — les deux branches
/// qu'il couvre sont mortes en pratique (`SessionState` garantit un
/// `currentExercise` non nul tant que `status == inProgress`), mais le
/// contenu affiché s'il fallait quand même les atteindre doit rester
/// utilisable.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, required this.actionLabel, required this.onAction});

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
