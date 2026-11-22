import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:math_core/models/input_device.dart';
import '../../core/effects/session_effects.dart';
import '../../core/state/session_controller.dart';
import '../exercise_prompt.dart';
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
const sessionCorrectionKey = ValueKey('session-correction');
ValueKey<String> keypadKeyKey(String name) => ValueKey('keypad-$name');

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.controller,
    this.effects = const NoSessionEffects(),
    this.onQuit,
  });

  final SessionController controller;

  /// The ✕ top left (Redesign phase): asks before quitting
  /// (`SessionFlowScreen`). `null`: no ✕ (tests that do not care).
  final VoidCallback? onQuit;

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
  }

  @override
  void dispose() {
    _chronoController.dispose();
    _feedbackController.dispose();
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final transition = theme.extension<AppMotion>()!.questionTransition;
    final correction = state.correction;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Column(
        children: [
          Padding(
            padding: metrics.rootPadding.copyWith(top: 8, bottom: 0),
            child: _TopBar(
              onQuit: widget.onQuit,
              // The question being corrected is already counted in outcomes.
              questionIndex:
                  state.outcomes.length + (correction == null ? 1 : 0),
              totalQuestions: widget.controller.config.exerciseCount,
              chrono: _chronoController,
              barColor: timerBarColor(theme, streakTier(state.currentStreak)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.rootPadding.left,
              ),
              // Large system text: the block shrinks as a whole rather than
              // overflow; the keypad below keeps its height.
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KeyedSubtree(
                        key: sessionQuestionKey,
                        child: AnimatedSwitcher(
                          duration: reduceMotion
                              ? Duration.zero
                              : transition.duration,
                          switchInCurve: transition.curve,
                          switchOutCurve: transition.curve,
                          child: ExercisePrompt(
                            key: ValueKey(exercise),
                            exercise: exercise,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _AnswerDisplay(
                        key: sessionAnswerKey,
                        typedDigits: correction == null
                            ? _typedDigits
                            : '${correction.exercise.correctAnswer}',
                        feedback: _feedbackController,
                        feedbackCorrect: _feedbackCorrect,
                        reduceMotion: reduceMotion,
                      ),
                      const SizedBox(height: 8),
                      // Always laid out, empty outside a correction: nothing
                      // moves when it appears. No words (Redesign phase):
                      // the wrong answer struck through, or an hourglass.
                      SizedBox(
                        key: sessionCorrectionKey,
                        height: 28,
                        child: switch (correction) {
                          null => null,
                          final c when c.isTimeout => Icon(
                            Icons.hourglass_empty,
                            size: 22,
                            color: theme.extension<AppPalette>()!.textMuted,
                            semanticLabel: "Time's up",
                          ),
                          final c => Text(
                            '${c.submittedValue}',
                            semanticsLabel: 'Your answer ${c.submittedValue}',
                            style: theme.textTheme.titleMedium?.digits.copyWith(
                              color: theme.extension<AppPalette>()!.textMuted,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: theme
                                  .extension<AppPalette>()!
                                  .textMuted,
                            ),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.rootPadding.left - metrics.keyGap,
              0,
              metrics.rootPadding.right - metrics.keyGap,
              metrics.rootPadding.bottom - metrics.keyGap,
            ),
            child: SizedBox(
              // Fixed height first, the operation takes what remains above
              // (`Expanded`) — nothing moves between questions
              // (`doc/design.md`: never a ratio of the screen).
              height: metrics.keypadHeight,
              child: _NumericKeypad(
                onDigit: (digit) => _appendDigit(digit, InputDevice.keypad),
                onBackspace: () => _backspace(InputDevice.keypad),
                onValidate: () => _submit(InputDevice.keypad),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onQuit,
    required this.questionIndex,
    required this.totalQuestions,
    required this.chrono,
    required this.barColor,
  });

  final VoidCallback? onQuit;
  final int questionIndex;
  final int totalQuestions;
  final Animation<double> chrono;

  /// Intensifies with the streak (`timerBarColor`); its size never changes.
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      children: [
        Row(
          children: [
            // Always 48 wide, so the counter never moves with or without it.
            SizedBox.square(
              dimension: 48,
              child: onQuit == null
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: colorScheme.onSurface),
                      tooltip: 'Quit',
                      onPressed: onQuit,
                    ),
            ),
            const Spacer(),
            Text(
              '$questionIndex / $totalQuestions',
              style: theme.textTheme.bodyLarge?.digits.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AnimatedBuilder(
            animation: chrono,
            builder: (context, _) => LinearProgressIndicator(
              value: 1 - chrono.value,
              minHeight: 5,
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
    this.reduceMotion = false,
  });

  final String typedDigits;
  final Animation<double> feedback;
  final bool? feedbackCorrect;

  /// The system's reduced-motion setting: the flash stays (and the sound and
  /// vibration), the scale and the shake go.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final style = theme.textTheme.headlineMedium?.copyWith(color: accent);
    final text = Container(
      constraints: const BoxConstraints(minWidth: 140),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: accent, width: 2)),
      ),
      child: Text(typedDigits, textAlign: TextAlign.center, style: style),
    );

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
        final scale = correct && !reduceMotion
            ? 1.0 + 0.06 * math.sin(t * math.pi)
            : 1.0;
        // Damped horizontal shake: oscillates then settles.
        final shakeDx = correct || reduceMotion
            ? 0.0
            : 8 * math.sin(t * math.pi * 4) * (1 - t);

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
                  subdued: true,
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
