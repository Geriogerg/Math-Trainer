import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.controller, required this.onRestart});

  final SessionController controller;

  /// Ramène à l'écran de sélection des types (pas
  /// `SessionController.restart()`, qui rejouerait silencieusement avec les
  /// mêmes types) — décision prise pour l'étape 3, commit C.
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final accuracyPercent = (result.accuracy * 100).round();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Session terminée', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text('Score : ${result.totalScore}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('${result.correctCount} / ${result.outcomes.length} bonnes réponses ($accuracyPercent %)'),
          const SizedBox(height: 8),
          Text('Temps moyen : ${result.averageElapsedMs.round()} ms'),
          const SizedBox(height: 32),
          FilledButton(onPressed: onRestart, child: const Text('Recommencer')),
        ],
      ),
    );
  }
}
