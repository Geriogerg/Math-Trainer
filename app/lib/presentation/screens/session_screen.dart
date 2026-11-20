import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/input_device.dart';
import '../../core/effects/session_effects.dart';
import '../../core/state/session_controller.dart';
import '../exercise_prompt.dart';
import '../exercise_type_labels.dart';
import '../kit/keypad_key.dart';
import '../streak_tier.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Longest possible answer: 10⁵ (powers); 7 leaves a margin without letting
/// wild input overflow the screen.
const _maxTypedDigits = 7;

/// The *physical* digit row, not the logical one: on an AZERTY keyboard,
/// these keys produce "& é " ' ( - è _ ç à" without Shift — the player must
/// be able to type digits without Shift, as on a numeric keypad.
final _digitKeys = {
  PhysicalKeyboardKey.digit0: '0',
  PhysicalKeyboardKey.digit1: '1',
  PhysicalKeyboardKey.digit2: '2',
  PhysicalKeyboardKey.digit3: '3',
  PhysicalKeyboardKey.digit4: '4',
  PhysicalKeyboardKey.digit5: '5',
  PhysicalKeyboardKey.digit6: '6',
  PhysicalKeyboardKey.digit7: '7',
  PhysicalKeyboardKey.digit8: '8',
  PhysicalKeyboardKey.digit9: '9',
  PhysicalKeyboardKey.numpad0: '0',
  PhysicalKeyboardKey.numpad1: '1',
  PhysicalKeyboardKey.numpad2: '2',
  PhysicalKeyboardKey.numpad3: '3',
  PhysicalKeyboardKey.numpad4: '4',
  PhysicalKeyboardKey.numpad5: '5',
  PhysicalKeyboardKey.numpad6: '6',
  PhysicalKeyboardKey.numpad7: '7',
  PhysicalKeyboardKey.numpad8: '8',
  PhysicalKeyboardKey.numpad9: '9',
};

/// Stable handles on what the Phase 5 beta-safety rule pins (keypad
/// geometry, question and answer positions):
/// `test/presentation/session_layout_pin_test.dart`.
const sessionQuestionKey = ValueKey('session-question');
const sessionAnswerKey = ValueKey('session-answer');
const sessionStreakLineKey = ValueKey('session-streak-line');
ValueKey<String> keypadKeyKey(String name) => ValueKey('keypad-$name');

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.controller,
    this.effects = const NoSessionEffects(),
  });

  final SessionController controller;

  /// Haptics (and sound, Phase 5): called after the controller has moved
  /// on, never awaited (`SessionEffects`).
  final SessionEffects effects;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  String _typedDigits = '';
  bool? _feedbackCorrect;

  /// Answers already seen by this screen: a rebuild with more means a new
  /// answer (a timeout's feedback plays once, not again when its correction
  /// pause ends).
  int _seenOutcomes = 0;

  /// `outcomes.length` of the question the timer bar is running for.
  int _chronoQuestion = 0;

  late final AnimationController _chronoController;
  late final AnimationController _feedbackController;

  /// The streak line's pulse when the streak reaches 5, 10, 20 (Phase 5
  /// commit 6): a scale transform — it moves nothing on screen.
  late final AnimationController _streakPulse;
  late final Animation<double> _streakScale;
  int _streakTier = 0;

  @override
  void initState() {
    super.initState();
    // No timeout (debug switch): the bar stays full.
    final timeout = widget.controller.questionTimeout;
    _chronoController = AnimationController(
      vsync: this,
      duration: timeout ?? Duration.zero,
    );
    if (timeout != null) _chronoController.forward();
    // Actual duration set just before each .forward() (AppMotion.feedback,
    // read from the theme — unavailable here, before the first frame).
    _feedbackController = AnimationController(
      vsync: this,
      duration: Duration.zero,
    );
    // Duration set from `AppMotion.pulse` before each run, like feedback.
    _streakPulse = AnimationController(vsync: this, duration: Duration.zero);
    _streakScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1), weight: 1),
    ]).animate(_streakPulse);
  }

  @override
  void didUpdateWidget(covariant SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The controller is the same object from one question to the next (only
    // its internal state changes): the number of answers tells a new
    // question — comparing exercises by value could miss one if the same
    // operation comes up twice in a row.
    final state = widget.controller.state;
    final outcomes = state.outcomes;
    if (state.isCorrecting) {
      // The bar freezes during the correction pause: no clock runs.
      _chronoController.stop();
    } else if (outcomes.length != _chronoQuestion) {
      _chronoQuestion = outcomes.length;
      if (widget.controller.questionTimeout != null) {
        _chronoController.forward(from: 0);
      }
    }

    // A timeout ends the question without going through _submit() (no
    // "submit" key pressed): without this check there would be no
    // flash/haptic, while a timeout counts as a wrong answer and must show
    // the same way (rule 14).
    if (outcomes.length > _seenOutcomes && outcomes.last.isTimeout) {
      _playFeedback(false);
      _safely(widget.effects.timedOut);
    }
    _seenOutcomes = outcomes.length;

    // Reaching 5, 10 or 20 in a row: a short pulse — none under the
    // system's reduced-motion setting. Losing the streak: no pulse.
    final tier = streakTier(state.currentStreak);
    if (tier > _streakTier && !MediaQuery.disableAnimationsOf(context)) {
      _streakPulse
        ..duration = Theme.of(context).extension<AppMotion>()!.pulse.duration
        ..forward(from: 0);
    }
    _streakTier = tier;
  }

  @override
  void dispose() {
    _chronoController.dispose();
    _feedbackController.dispose();
    _streakPulse.dispose();
    super.dispose();
  }

  void _appendDigit(String digit, InputDevice device) {
    if (widget.controller.state.isCorrecting) return;
    widget.controller.registerActivity(device);
    _safely(() => widget.effects.keyPressed(device));
    if (_typedDigits.length >= _maxTypedDigits) return;
    setState(() => _typedDigits += digit);
  }

  /// Physical keyboard (web, desktop, tablet with keyboard): without it,
  /// every digit is clicked on the keypad with the mouse — the game sells
  /// on speed. Same paths as the touch keypad, hence the same timing and the
  /// same activity detection.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final digit = _digitKeys[event.physicalKey];
    if (digit != null) {
      _appendDigit(digit, InputDevice.keyboard);
      return KeyEventResult.handled;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _backspace(InputDevice.keyboard);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // No repeat: holding Enter must not submit the next question before it
      // is even read.
      if (event is KeyDownEvent) _submit(InputDevice.keyboard);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _backspace(InputDevice device) {
    if (widget.controller.state.isCorrecting) return;
    widget.controller.registerActivity(device);
    _safely(() => widget.effects.keyPressed(device));
    if (_typedDigits.isEmpty) return;
    setState(
      () => _typedDigits = _typedDigits.substring(0, _typedDigits.length - 1),
    );
  }

  void _submit(InputDevice device) {
    final exercise = widget.controller.state.currentExercise;
    if (exercise == null || widget.controller.state.isCorrecting) return;
    final value = int.tryParse(_typedDigits);
    if (value == null) return;

    // Computed before `submitAnswer`: the domain already exposes
    // `isCorrectAnswer`, no need to wait for the controller to know which
    // flash to trigger. `submitAnswer` is called right after, with no delay —
    // the controller's internal timing (used for the score) stays exact.
    final isCorrect = exercise.isCorrectAnswer(value);
    widget.controller.submitAnswer(value, device: device);
    _playFeedback(isCorrect);
    _safely(
      () => widget.effects.answered(
        correct: isCorrect,
        streak: widget.controller.state.currentStreak,
      ),
    );
  }

  /// An effect that throws (an audio context the browser refused, a
  /// vibration API missing) must never break the game.
  void _safely(void Function() effect) {
    try {
      effect();
    } on Object catch (_) {
      // Fire and forget: the answer is already recorded, the next question
      // already chosen.
    }
  }

  /// Shared by an explicit submit and a timeout (`didUpdateWidget`) — in
  /// both cases the answer to the question that just ended is known, only
  /// the trigger differs.
  void _playFeedback(bool isCorrect) {
    final motion = Theme.of(context).extension<AppMotion>()!.feedback;
    _feedbackController.duration = motion.duration;
    setState(() {
      _typedDigits = '';
      _feedbackCorrect = isCorrect;
    });
    _feedbackController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _feedbackCorrect = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final exercise = state.currentExercise;
    if (exercise == null) {
      return EmptyState(
        message: 'No question to show.',
        actionLabel: 'Quit',
        onAction: () => Navigator.of(context).maybePop(),
      );
    }

    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    // Whole part, never the raw hundredths (`Level` is an `int` at runtime:
    // interpolating it directly would print 1200 for level 12).
    final level =
        (widget.controller.config.levels[exercise.type] ?? Level.floor).whole;
    // A placement's questions move with the answers: the frozen level would
    // be wrong, and showing the level being probed would steer the player.
    final levelText = widget.controller.config.kind.isPlacement
        ? 'finding your level'
        : 'level $level';
    final correction = state.correction;
    // During the correction pause the answer field shows the correct
    // answer; the caption says what was given instead.
    final caption = correction == null
        ? ''
        : correction.isTimeout
        ? "Time's up"
        : 'Your answer: ${correction.submittedValue}';

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          Padding(
            padding: metrics.rootPadding,
            child: _TopBar(
              // The question being corrected is already counted in outcomes.
              questionIndex:
                  state.outcomes.length + (correction == null ? 1 : 0),
              totalQuestions: widget.controller.config.exerciseCount,
              chrono: _chronoController,
              barColor: timerBarColor(theme, streakTier(state.currentStreak)),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _streakScale,
                    child: Text.rich(
                      key: sessionStreakLineKey,
                      TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.extension<AppPalette>()!.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${exerciseTypeLabel(exercise.type)} · $levelText',
                          ),
                          // Streak shown only if > 0: no "streak 0" noise on
                          // every first question (`doc/decisions.md` —
                          // currentStreak shown during the session). Its
                          // colour steps up at 5, 10, 20 (Phase 5); the
                          // number itself says it, never the colour alone.
                          if (state.currentStreak > 0)
                            TextSpan(
                              text: ' · streak ${state.currentStreak}',
                              style: TextStyle(
                                color: streakTextColor(
                                  theme,
                                  streakTier(state.currentStreak),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  KeyedSubtree(
                    key: sessionQuestionKey,
                    child: AnimatedSwitcher(
                      duration: theme
                          .extension<AppMotion>()!
                          .questionTransition
                          .duration,
                      switchInCurve: theme
                          .extension<AppMotion>()!
                          .questionTransition
                          .curve,
                      switchOutCurve: theme
                          .extension<AppMotion>()!
                          .questionTransition
                          .curve,
                      child: ExercisePrompt(
                        key: ValueKey(exercise),
                        exercise: exercise,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _AnswerDisplay(
                    key: sessionAnswerKey,
                    typedDigits: correction == null
                        ? _typedDigits
                        : '${correction.exercise.correctAnswer}',
                    feedback: _feedbackController,
                    feedbackCorrect: _feedbackCorrect,
                  ),
                  const SizedBox(height: 8),
                  // Always laid out, empty outside a correction: nothing
                  // moves when it appears.
                  Text(
                    caption,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.extension<AppPalette>()!.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            // Fixed height first, the operation takes what remains above
            // (`Expanded`) — nothing moves between questions (`doc/design.md`:
            // never a ratio of the screen, see `AppMetrics`).
            height: metrics.keypadHeight,
            child: _NumericKeypad(
              onDigit: (digit) => _appendDigit(digit, InputDevice.keypad),
              onBackspace: () => _backspace(InputDevice.keypad),
              onValidate: () => _submit(InputDevice.keypad),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.questionIndex,
    required this.totalQuestions,
    required this.chrono,
    required this.barColor,
  });

  final int questionIndex;
  final int totalQuestions;
  final Animation<double> chrono;

  /// Intensifies with the streak (`timerBarColor`); its size never changes.
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '$questionIndex / $totalQuestions',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: AnimatedBuilder(
            animation: chrono,
            builder: (context, _) => LinearProgressIndicator(
              value: 1 - chrono.value,
              minHeight: 4,
              backgroundColor: colorScheme.outline,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// The answer being typed. The feedback flash/motion (rule 14: never colour
/// alone) applies here, not to the whole screen (`doc/design.md`: "flash
/// [...] on the input field").
class _AnswerDisplay extends StatelessWidget {
  const _AnswerDisplay({
    super.key,
    required this.typedDigits,
    required this.feedback,
    required this.feedbackCorrect,
  });

  final String typedDigits;
  final Animation<double> feedback;
  final bool? feedbackCorrect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.headlineMedium;
    final text = Text(typedDigits, style: style);

    return AnimatedBuilder(
      animation: feedback,
      builder: (context, child) {
        final correct = feedbackCorrect;
        if (correct == null) return child!;

        final t = feedback.value;
        final flashColor = correct
            ? theme.colorScheme.onSurface
            : theme.colorScheme.error;
        final opacity = (1 - t).clamp(0.0, 1.0);
        // Scale 1.0 → 1.06 → 1.0 (doc/design.md): a sine bump peaks in the
        // middle of the animation.
        final scale = correct ? 1.0 + 0.06 * math.sin(t * math.pi) : 1.0;
        // Damped horizontal shake: oscillates then settles.
        final shakeDx = correct ? 0.0 : 8 * math.sin(t * math.pi * 4) * (1 - t);

        return Transform.translate(
          offset: Offset(shakeDx, 0),
          child: Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: flashColor.withValues(alpha: opacity * 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: child,
              ),
            ),
          ),
        );
      },
      child: text,
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onValidate,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onValidate;

  static const _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _digitRows)
          Expanded(
            child: Row(
              children: [
                for (final digit in row)
                  Expanded(
                    child: KeypadKey.digit(
                      digit,
                      key: keypadKeyKey(digit),
                      onTap: () => onDigit(digit),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeypadKey.icon(
                  Icons.backspace_outlined,
                  key: keypadKeyKey('backspace'),
                  semanticLabel: 'Backspace',
                  onTap: onBackspace,
                ),
              ),
              Expanded(
                child: KeypadKey.digit(
                  '0',
                  key: keypadKeyKey('0'),
                  onTap: () => onDigit('0'),
                ),
              ),
              Expanded(
                child: KeypadKey.icon(
                  Icons.check,
                  key: keypadKeyKey('submit'),
                  semanticLabel: 'Submit',
                  onTap: onValidate,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
