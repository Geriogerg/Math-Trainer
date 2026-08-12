import 'package:flutter/material.dart';

import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final result = controller.result;
    final status = controller.state.status;
    final title = status == SessionStatus.interrupted ? 'Session interrompue' : 'Session terminée';
    final breakdown = result.scoreBreakdown;
    final labelStyle = theme.textTheme.bodyMedium;

    return SingleChildScrollView(
      padding: theme.extension<AppMetrics>()!.rootPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 24),
          // Aucun changement de niveau pour une session interrompue —
          // countsForLevels est resté à false, lastLevelUpdates ne se peuple
          // jamais (`doc/decisions.md`).
          if (status == SessionStatus.finished) ...[
            for (final type in controller.config.enabledTypes)
              _LevelChangeRow(
                label: exerciseTypeLabel(type),
                before: controller.config.levels[type] ?? 1,
                updates: controller.lastLevelUpdates,
                type: type,
              ),
            const SizedBox(height: 16),
          ],
          Text(
            'Score : ${result.totalScore}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Base : ${breakdown.base}', textAlign: TextAlign.center, style: labelStyle),
          Text(
            'Bonus de vitesse : ${breakdown.speedBonus}',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          Text(
            'Bonus de série : ${breakdown.streakBonus}',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          Text(
            'Bonus de difficulté : ${breakdown.difficultyBonus}',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          const SizedBox(height: 16),
          // Décompte brut, jamais un pourcentage présenté comme un progrès
          // (`doc/design.md`) : le taux de réussite converge vers p_cible par
          // construction, il ne mesure plus rien (`doc/decisions.md`).
          Text(
            '${result.correctCount} justes · ${result.wrongCount} fausses · '
            '${result.timeoutCount} hors délai',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Temps moyen : ${result.averageElapsedMs.round()} ms',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Meilleure série : ${result.bestStreak}',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Types joués : ${controller.config.enabledTypes.map(exerciseTypeLabel).join(', ')}',
            textAlign: TextAlign.center,
            style: labelStyle,
          ),
          const SizedBox(height: 32),
          // Rejouer dominant à droite, Nouvelle sélection à gauche
          // (`doc/design.md`).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onExitToSelection, child: const Text('Nouvelle sélection')),
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
            ],
          ),
          if (restartError != null) ...[
            const SizedBox(height: 8),
            Text(
              restartError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Anime `before` → niveau après (`AppMotion.levelUp`, 600 ms) une fois
/// [updates] résolu. Tant que `null` (calcul encore en tâche de fond),
/// affiche `before` sans animation plutôt qu'un état vide.
class _LevelChangeRow extends StatelessWidget {
  const _LevelChangeRow({
    required this.label,
    required this.before,
    required this.updates,
    required this.type,
  });

  final String label;
  final int before;
  final Map<ExerciseType, LevelCacheEntry>? updates;
  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;

    if (updates == null) {
      return Text('$label — niveau $before', textAlign: TextAlign.center, style: style);
    }

    // Type resté sous n_min cette session : pas d'entrée, pas de changement.
    final after = updates![type]?.level ?? before;
    final motion = theme.extension<AppMotion>()!.levelUp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: before.toDouble(), end: after.toDouble()),
      duration: motion.duration,
      curve: motion.curve,
      builder: (context, value, _) =>
          Text('$label — niveau ${value.round()}', textAlign: TextAlign.center, style: style),
    );
  }
}
