import 'package:flutter/material.dart';

import '../../core/domain/models/answer_result.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import '../exercise_prompt.dart';
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

  /// Immediate replay: same types, updated levels, new seed (step 4.2,
  /// commit C — `doc/decisions.md`).
  final VoidCallback onPlayAgain;

  /// Goes back to the type selection screen, to change it.
  final VoidCallback onExitToSelection;

  final bool isRestarting;
  final String? restartError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = controller.result;
    final status = controller.state.status;
    final title = status == SessionStatus.interrupted
        ? 'Session interrupted'
        : 'Session complete';
    final breakdown = result.scoreBreakdown;
    final labelStyle = theme.textTheme.bodyMedium;
    final mistakes = result.outcomes.where((o) => !o.isCorrect).toList();
    final metrics = theme.extension<AppMetrics>()!;

    final results = LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: metrics.rootPadding.copyWith(bottom: 0),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                // No level change for an interrupted session — countsForLevels
                // stayed false, lastLevelUpdates is never set
                // (`doc/decisions.md`).
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
                  'Score: ${result.totalScore}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Base: ${breakdown.base}',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                Text(
                  'Speed bonus: ${breakdown.speedBonus}',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                Text(
                  'Streak bonus: ${breakdown.streakBonus}',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                // 0 for every player below a meaningful level
                // (`_difficultyMultiplier(1) == 1`) — a line at 0 for most
                // sessions of the first weeks teaches nothing.
                if (breakdown.difficultyBonus != 0)
                  Text(
                    'Difficulty bonus: ${breakdown.difficultyBonus}',
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                const SizedBox(height: 16),
                // Raw count, never a percentage presented as progress
                // (`doc/design.md`): accuracy converges to p_cible by
                // construction, it measures nothing (`doc/decisions.md`).
                Text(
                  '${result.correctCount} right · ${result.wrongCount} wrong · '
                  '${result.timeoutCount} timed out',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Average time: ${result.averageElapsedMs.round()} ms',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Best streak: ${result.bestStreak}',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Types played: ${controller.config.enabledTypes.map(exerciseTypeLabel).join(', ')}',
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
                // Mistakes review (`doc/design.md`, Phase 0 commit 9): every
                // wrong answer and timeout, in play order, with its correct
                // answer — the last question's included, which had no
                // correction pause.
                if (mistakes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Mistakes',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final mistake in mistakes) _MistakeRow(outcome: mistake),
                ],
                if (controller.persistenceFailed) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Game not saved: it does not count in '
                    'your history or your levels.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Replays the same write (`retryPersistence`): useful when
                  // the failure was transient (storage briefly unavailable).
                  // Disabled while an attempt is running.
                  TextButton(
                    onPressed: controller.isRetryingPersistence
                        ? null
                        : controller.retryPersistence,
                    child: const Text('Retry saving'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // The actions stay pinned under the scrolling results: with a long
    // mistakes list, "Play again" must not need a scroll — the "play,
    // replay" loop is the point of this screen.
    return Column(
      children: [
        Expanded(child: results),
        Padding(
          padding: metrics.rootPadding.copyWith(top: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Centred (`doc/design.md`) — Play again stays visually
              // dominant through its filled style (`FilledButton`), not its
              // position.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: onExitToSelection,
                    child: const Text('New selection'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: isRestarting ? null : onPlayAgain,
                    child: isRestarting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Play again'),
                  ),
                ],
              ),
              if (restartError != null) ...[
                const SizedBox(height: 8),
                Text(
                  restartError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// "7 × 8 = 56   your answer 54" — the operation as displayed in the session,
/// its correct answer, then what was given (or "timed out") in muted text.
class _MistakeRow extends StatelessWidget {
  const _MistakeRow({required this.outcome});

  final AnswerResult outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium;
    final given = outcome.isTimeout
        ? 'timed out'
        : 'your answer ${outcome.submittedValue}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExercisePrompt(exercise: outcome.exercise, style: style),
          Text(' = ${outcome.exercise.correctAnswer}', style: style),
          const SizedBox(width: 12),
          Text(
            given,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.extension<AppPalette>()!.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animates `before` → level after (`AppMotion.levelUp`, 600 ms) once
/// [updates] has resolved. While `null` (computation still in the
/// background), shows `before` without animation rather than an empty state.
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
      return Text(
        '$label — level $before',
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final entry = updates![type];
    if (entry == null) {
      // Type stayed below n_min this session: no entry computed, so nothing
      // to animate — distinct from "evaluated, level unchanged" (the player
      // could not tell the difference if both rendered the same).
      return Text(
        '$label — level $before (not enough answers to count)',
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final motion = theme.extension<AppMotion>()!.levelUp;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: before.toDouble(), end: entry.level.toDouble()),
      duration: motion.duration,
      curve: motion.curve,
      builder: (context, value, _) => Text(
        '$label — level ${value.round()}',
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}
