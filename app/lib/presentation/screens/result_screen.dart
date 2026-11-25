import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';

import 'package:math_core/method/method.dart';
import 'package:math_core/method/method_for.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import '../../core/effects/session_effects.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import '../exercise_prompt.dart';
import '../method_labels.dart';
import '../method_view.dart';
import '../number_format.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import '../tips/tips.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.controller,
    required this.onPlayAgain,
    required this.onExitToSelection,
    required this.isRestarting,
    required this.restartError,
    this.effects = const NoSessionEffects(),
    this.showMethods = false,
    this.onMoreTips,
  });

  /// A Method under each wrong answer and timeout (`doc/levels.md`
  /// section 9): Basics and Advanced games; never Tables mode.
  final bool showMethods;

  /// "More tips": the Tips page at the method's tip ([tipFor]), or at the
  /// operation's section for a fallback.
  final void Function(ExerciseType type, Tip? tip)? onMoreTips;

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
    final interrupted = status == SessionStatus.interrupted;
    final title = interrupted ? 'Session interrupted' : 'Session complete';
    final breakdown = result.scoreBreakdown;
    final labelStyle = theme.textTheme.bodyMedium;
    // Each mistake with its question's pattern family, replayed from the
    // game's config (families are never stored).
    final families = showMethods
        ? gamePatterns(controller.config, result.outcomes.length)
        : const [];
    final mistakes = [
      for (final (i, o) in result.outcomes.indexed)
        if (!o.isCorrect)
          (outcome: o, family: showMethods ? families[i] : null),
    ];
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
                // Training and practice move no level: nothing to show.
                if (status == SessionStatus.finished &&
                    controller.config.kind.movesLevels) ...[
                  for (final type in controller.config.enabledTypes)
                    _LevelChangeRow(
                      label: exerciseTypeLabel(type),
                      before: controller.config.levels[type] ?? Level.zero,
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
                ...[
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
                  // 0 at level 0 (`_difficultyMultiplier(0) == 1`) — a
                  // line at 0 for a player's first games teaches nothing.
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
                  for (final (i, mistake) in mistakes.indexed)
                    MistakeRow(
                      key: ValueKey('mistake-$i'),
                      outcome: mistake.outcome,
                      method: showMethods
                          ? methodFor(
                              mistake.outcome.exercise,
                              family: mistake.family,
                            )
                          : null,
                      onMoreTips: onMoreTips,
                    ),
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
              // A Wrap, not a Row: with a large system text size the two no
              // longer fit side by side and stack instead of overflowing.
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
/// hourglass for a timeout: as the game's own correction (no words). A
/// Wrap: a 9-digit sum and its answer do not fit one phone line. With a
/// [method], a "Method" button under it opens the steps in place.
class MistakeRow extends StatefulWidget {
  const MistakeRow({
    super.key,
    required this.outcome,
    this.method,
    this.onMoreTips,
  });

  final AnswerResult outcome;
  final Method? method;
  final void Function(ExerciseType type, Tip? tip)? onMoreTips;

  @override
  State<MistakeRow> createState() => _MistakeRowState();
}

class _MistakeRowState extends State<MistakeRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final method = widget.method;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _MistakeLine(outcome: widget.outcome),
          if (method != null)
            Semantics(
              expanded: _open,
              child: AppButton.secondary(
                label: _open ? 'Hide method' : 'Method',
                onPressed: () => setState(() => _open = !_open),
              ),
            ),
          if (method != null && _open)
            _MethodPanel(
              method: method,
              type: widget.outcome.exercise.type,
              onMoreTips: widget.onMoreTips,
              theme: theme,
            ),
        ],
      ),
    );
  }
}

/// The strategy's name, its lines, "More tips" (`doc/levels.md` section 9:
/// minimal text — the name and arithmetic, no sentences).
class _MethodPanel extends StatelessWidget {
  const _MethodPanel({
    required this.method,
    required this.type,
    required this.onMoreTips,
    required this.theme,
  });

  final Method method;
  final ExerciseType type;
  final void Function(ExerciseType type, Tip? tip)? onMoreTips;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final metrics = theme.extension<AppMetrics>()!;
    final onMoreTips = this.onMoreTips;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh, // as the stat tiles
        borderRadius: BorderRadius.circular(metrics.radius / 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(methodName(method, type), style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          MethodLines(method: method, style: theme.textTheme.bodyLarge?.digits),
          if (onMoreTips != null)
            Align(
              alignment: Alignment.centerRight,
              child: AppButton.secondary(
                label: 'More tips',
                onPressed: () => onMoreTips(type, tipFor(method)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MistakeLine extends StatelessWidget {
  const _MistakeLine({required this.outcome});

  final AnswerResult outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.titleMedium;
    final muted = theme.extension<AppPalette>()!.textMuted;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 2,
      children: [
        ExercisePrompt(exercise: outcome.exercise, style: style),
        Text(
          ' = ${groupedNumber(outcome.exercise.correctAnswer)}',
          style: style,
        ),
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
            groupedNumber(outcome.submittedValue),
            semanticsLabel: 'Your answer ${outcome.submittedValue}',
            style: theme.textTheme.bodyLarge?.digits.copyWith(
              color: muted,
              decoration: TextDecoration.lineThrough,
              decorationColor: muted,
            ),
          ),
      ],
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
      (e) => e.value.level.whole > (before[e.key] ?? Level.zero).whole,
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
