import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.onPlayAgain,
    required this.onExitToSelection,
    required this.isRestarting,
    required this.restartError,
  });

  final SessionController controller;

  /// Relance immédiate : mêmes types, niveaux actualisés, nouvelle seed
  /// (étape 4.2, commit C — `doc/decisions.md`).
  final VoidCallback onPlayAgain;

  /// Ramène à l'écran de sélection des types, pour en changer.
  final VoidCallback onExitToSelection;

  final bool isRestarting;
  final String? restartError;

  @override
  Widget build(BuildContext context) {
    final result = controller.result;
    final accuracyPercent = (result.accuracy * 100).round();
    final title = controller.state.status == SessionStatus.interrupted
        ? 'Session interrompue'
        : 'Session terminée';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text(
              'Score : ${result.totalScore}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${result.correctCount} / ${result.outcomes.length} bonnes réponses ($accuracyPercent %)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('Temps moyen : ${result.averageElapsedMs.round()} ms', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: isRestarting ? null : onPlayAgain,
              child: isRestarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Rejouer'),
            ),
            if (restartError != null) ...[
              const SizedBox(height: 8),
              Text(
                restartError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(onPressed: onExitToSelection, child: const Text('Nouvelle sélection')),
          ],
        ),
      ),
    );
  }
}
