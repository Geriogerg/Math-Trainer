import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';

import 'package:math_core/models/session_kind.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import '../../core/effects/session_effects.dart';
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
    this.effects = const NoSessionEffects(),
  });

  final SessionController controller;

  /// The level-up sound (Phase 5 commit 6), once per result.
  final SessionEffects effects;

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
    final isPlacement = controller.config.kind.isPlacement;
    final interrupted = status == SessionStatus.interrupted;
    final title = isPlacement
        ? (interrupted ? 'Placement interrupted' : 'Your starting levels')
        : (interrupted ? 'Session interrupted' : 'Session complete');
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
                // A placement shows where the player starts, not a change
                // from the staircases' common start; no score (it measures
                // nothing there).
                if (isPlacement) ...[
                  // Interrupted: the title says it, nothing moved (labels
                  // only, Redesign phase).
                  if (!interrupted)
                    // The placement test: the four basic operations; a type
                    // placement: the ones it placed.
                    for (final type
                        in controller.config.enabledTypes.toList()
                          ..sort((a, b) => a.index - b.index))
                      Text(
                        controller.lastLevelUpdates?[type] == null
                            ? '${exerciseTypeLabel(type)} — …'
                            : '${exerciseTypeLabel(type)} — level '
                                  '${controller.lastLevelUpdates![type]!.level.whole}',
                        textAlign: TextAlign.center,
                        style: labelStyle,
                      ),
                  const SizedBox(height: 16),
                  // Training moves no level: nothing to show.
                ] else if (status == SessionStatus.finished &&
                    controller.config.kind != SessionKind.training) ...[
                  for (final type in controller.config.enabledTypes)
                    _LevelChangeRow(
                      label: exerciseTypeLabel(type),
                      before: controller.config.levels[type] ?? Level.floor,
                      updates: controller.lastLevelUpdates,
                      type: type,
                    ),
                  _LevelUpCue(
                    leveledUp: leveledUp(
                      controller.config.levels,
                      controller.lastLevelUpdates,
                    ),
                    effects: effects,
                  ),
                  const SizedBox(height: 16),
                ],
                if (!isPlacement) ...[
                  Center(
                    child: SizedBox(
                      width: 160,
                      child: StatTile(
                        value: '${result.totalScore}',
                        label: 'Score',
                        emphasis: true,
                      ),
                    ),
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
                ],
                // Raw count, never a percentage presented as progress
                // (`doc/design.md`): accuracy converges to p_cible by
                // construction, it measures nothing (`doc/decisions.md`).
                StatTileRow(
                  tiles: [
                    StatTile(value: '${result.correctCount}', label: 'Right'),
                    StatTile(value: '${result.wrongCount}', label: 'Wrong'),
                    StatTile(
                      value: '${result.timeoutCount}',
                      label: 'Timed out',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StatTileRow(
                  tiles: [
                    StatTile(
                      value: '${result.averageElapsedMs.round()} ms',
                      label: 'Average time',
                    ),
                    StatTile(
                      value: '${result.bestStreak}',
                      label: 'Best streak',
                    ),
                  ],
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
                    'Not saved',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Replays the same write (`retryPersistence`): useful when
                  // the failure was transient (storage briefly unavailable).
                  // Disabled while an attempt is running.
                  AppButton.secondary(
                    onPressed: controller.isRetryingPersistence
                        ? null
                        : controller.retryPersistence,
                    label: 'Retry saving',
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
              // dominant through its filled style (`AppButton.primary`), not
              // its position.
              // Every result, a placement's too (Redesign close-out, plan
              // v3.0): a Wrap, not a Row — with a large system text size
              // the two no longer fit side by side and stack instead of
              // overflowing.
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  AppButton.secondary(
                    onPressed: onExitToSelection,
                    label: 'Home',
                  ),
                  AppButton.primary(
                    onPressed: onPlayAgain,
                    busy: isRestarting,
                    label: 'Play again',
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

/// "7 × 8 = 56   ~~54~~" — the operation as displayed in the session, its
/// correct answer, then what was given struck through in muted text, or an
/// hourglass for a timeout: as the game's own correction (no words).
class _MistakeRow extends StatelessWidget {
  const _MistakeRow({required this.outcome});

  final AnswerResult outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium;
    final muted = theme.extension<AppPalette>()!.textMuted;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ExercisePrompt(exercise: outcome.exercise, style: style),
          Text(' = ${outcome.exercise.correctAnswer}', style: style),
          const SizedBox(width: 12),
          if (outcome.isTimeout)
            Icon(
              Icons.hourglass_empty,
              size: 18,
              color: muted,
              semanticLabel: 'Timed out',
            )
          else
            Text(
              '${outcome.submittedValue}',
              semanticsLabel: 'Your answer ${outcome.submittedValue}',
              style: theme.textTheme.bodyLarge?.digits.copyWith(
                color: muted,
                decoration: TextDecoration.lineThrough,
                decorationColor: muted,
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
  final Level before;
  final Map<ExerciseType, LevelCacheEntry>? updates;
  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;

    if (updates == null) {
      return Text(
        '$label — level ${before.whole}',
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
        '$label — level ${before.whole} (not enough answers to count)',
        textAlign: TextAlign.center,
        style: style,
      );
    }

    final motion = theme.extension<AppMotion>()!.levelUp;
    // Reduced motion: the final level at once, no count-up, no pulse.
    final reduced = MediaQuery.disableAnimationsOf(context);
    // The whole level animates (truncated, like everywhere it is shown),
    // and a bar shows the progress inside it (owner, end of Phase 1): a
    // session that moves the level by less than one step still visibly
    // counts. Crossing a whole level, the bar wraps from full to empty
    // while the number goes up — the move is in the number and the bar's
    // length, never in a colour alone (rule 14).
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: before.value, end: entry.level.value),
      duration: reduced ? Duration.zero : motion.duration,
      curve: motion.curve,
      builder: (context, value, _) => Column(
        children: [
          Text(
            '$label — level ${value.floor()}',
            textAlign: TextAlign.center,
            style: style,
          ),
          // The moment the whole number goes up (Phase 5 commit 6): a mark
          // in words — never the colour alone — that pulses once.
          if (value.floor() > before.whole) const _LevelUpMark(),
          const SizedBox(height: 4),
          _ProgressInsideLevel(fraction: value - value.floor()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// How far the player is inside their whole level, 0 to 1 — the hundredths
/// the whole-number label leaves out.
class _ProgressInsideLevel extends StatelessWidget {
  const _ProgressInsideLevel({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          semanticsLabel: 'Progress toward the next level',
          value: fraction,
          minHeight: 6,
          backgroundColor: theme.colorScheme.outline,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
      ),
    );
  }
}

/// Whether any whole level went up this game (`lastLevelUpdates` against
/// the levels the game froze). `null` updates (not computed yet, or an
/// interrupted game): no.
bool leveledUp(
  Map<ExerciseType, Level> before,
  Map<ExerciseType, LevelCacheEntry>? updates,
) =>
    updates != null &&
    updates.entries.any(
      (e) => e.value.level.whole > (before[e.key] ?? Level.floor).whole,
    );

/// "Level up", under the number that just went up: pulses once as it
/// appears (`AppMotion.pulse`), still under reduced motion.
class _LevelUpMark extends StatefulWidget {
  const _LevelUpMark();

  @override
  State<_LevelUpMark> createState() => _LevelUpMarkState();
}

class _LevelUpMarkState extends State<_LevelUpMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Duration.zero,
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.18), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 1.18, end: 1), weight: 1),
  ]).animate(_pulse);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pulse.isAnimating || _pulse.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) return;
    _pulse
      ..duration = Theme.of(context).extension<AppMotion>()!.pulse.duration
      ..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: _scale,
      child: Text(
        '▲ Level up',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Plays the level-up sound once, when the game's level updates show a
/// whole level gained (they arrive after the result screen is up).
class _LevelUpCue extends StatefulWidget {
  const _LevelUpCue({required this.leveledUp, required this.effects});

  final bool leveledUp;
  final SessionEffects effects;

  @override
  State<_LevelUpCue> createState() => _LevelUpCueState();
}

class _LevelUpCueState extends State<_LevelUpCue> {
  bool _played = false;

  void _maybePlay() {
    if (_played || !widget.leveledUp) return;
    _played = true;
    try {
      widget.effects.levelUp();
    } on Object catch (_) {
      // Fire and forget, like every effect.
    }
  }

  @override
  void initState() {
    super.initState();
    _maybePlay();
  }

  @override
  void didUpdateWidget(_LevelUpCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybePlay();
  }

  // Lays out nothing: a cue, not a part of the screen.
  @override
  Widget build(BuildContext context) => const SizedBox();
}
