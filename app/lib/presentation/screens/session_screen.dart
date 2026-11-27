import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:math_core/models/input_device.dart';
import '../../core/effects/session_effects.dart';
import '../../core/state/session_controller.dart';
import '../exercise_prompt.dart';
import '../number_format.dart';
import '../kit/numeric_keypad.dart';
import '../spoken_prompt.dart';
import '../streak_tier.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

export '../kit/numeric_keypad.dart' show keypadKeyKey;

/// Ten digits (plan v3.1, Levels phase commit 5): every answer of the tiers
/// fits with room to spare (the largest, 200², has five), and the grouped
/// display ("1 234 567 890") still fits a phone.
const _maxTypedDigits = 10;

/// Stable handles on what the Phase 5 beta-safety rule pins (keypad
/// geometry, question and answer positions):
/// `test/presentation/session_layout_pin_test.dart`.
const sessionQuestionKey = ValueKey('session-question');
const sessionAnswerKey = ValueKey('session-answer');
const sessionCorrectionKey = ValueKey('session-correction');

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.controller,
    this.effects = const NoSessionEffects(),
    this.onQuit,
    this.header,
  });

  final SessionController controller;

  /// Between the counter and the timer bar: a duel's lanes (Phase 7).
  /// `null` for a game — its geometry is pinned
  /// (`session_layout_pin_test.dart`).
  final Widget? header;

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

  /// The time left was said for the current question (Phase 6b commit 6).
  bool _lowTimeSaid = false;

  /// When a screen reader hears that time runs out.
  static const _lowTimeLeft = Duration(seconds: 10);

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
    _chronoController.addListener(_sayLowTime);
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
      _lowTimeSaid = false;
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
      final missed = outcomes.last.exercise;
      _announce(
        "Time's up. ${spokenPrompt(missed)} is ${missed.correctAnswer}.",
      );
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
    final digit = physicalDigitKeys[event.physicalKey];
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
    _announce(
      isCorrect
          ? 'Right'
          : 'Wrong. ${spokenPrompt(exercise)} is ${exercise.correctAnswer}.',
    );
    _safely(
      () => widget.effects.answered(
        correct: isCorrect,
        streak: widget.controller.state.currentStreak,
      ),
    );
  }

  /// Says [message] to a screen reader, politely (Phase 6b commit 6,
  /// review M17: nothing said right or wrong, nor the time). Fire and
  /// forget, like the other effects.
  void _announce(String message) {
    if (!mounted) return;
    final view = View.of(context);
    _safely(
      () => SemanticsService.sendAnnouncement(
        view,
        message,
        TextDirection.ltr,
      ).ignore(),
    );
  }

  /// Once a question, when [_lowTimeLeft] remains.
  void _sayLowTime() {
    final timeout = widget.controller.questionTimeout;
    if (timeout == null || _lowTimeSaid) return;
    final left = timeout * (1 - _chronoController.value);
    if (left <= _lowTimeLeft && left > Duration.zero) {
      _lowTimeSaid = true;
      _announce('${_lowTimeLeft.inSeconds} seconds left');
    }
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
              header: widget.header,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.rootPadding.left,
              ),
              // Large system text: the block shrinks as a whole rather than
              // overflow; the keypad below keeps its height. The width an
              // arithmetic prompt has before it stacks on two lines is the
              // block's (`ExercisePrompt.maxWidth`).
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = promptStacks(
                    context,
                    exercise,
                    maxWidth: constraints.maxWidth,
                  );
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        // A stacked question: the answer right-aligned under
                        // it, on the units column (`doc/levels.md` section 6).
                        crossAxisAlignment: stacked
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.center,
                        children: [
                          // A live region: each new question is read out
                          // (Phase 6b commit 6, review M17).
                          Semantics(
                            container: true,
                            liveRegion: true,
                            label:
                                'Question ${state.outcomes.length + (correction == null ? 1 : 0)} '
                                'of ${widget.controller.config.exerciseCount}: '
                                '${spokenPrompt(exercise)}',
                            excludeSemantics: true,
                            child: KeyedSubtree(
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
                                  maxWidth: constraints.maxWidth,
                                ),
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
                            alignRight: stacked,
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
                                groupedNumber(c.submittedValue),
                                semanticsLabel:
                                    'Your answer ${c.submittedValue}',
                                style: theme.textTheme.titleMedium?.digits
                                    .copyWith(
                                      color: theme
                                          .extension<AppPalette>()!
                                          .textMuted,
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
                  );
                },
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
              child: NumericKeypad(
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
    this.header,
  });

  /// Between the counter and the timer bar (a duel's lanes, as in
  /// `doc/mockups/online.html`).
  final Widget? header;

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
        if (header case final header?) ...[const SizedBox(height: 4), header],
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: AnimatedBuilder(
            animation: chrono,
            // Spoken as the seconds left (Phase 6b commit 6, review M17).
            builder: (context, _) => Semantics(
              container: true,
              label: 'Time left',
              value: timeLeftWords(chrono),
              excludeSemantics: true,
              child: LinearProgressIndicator(
                value: 1 - chrono.value,
                minHeight: 5,
                backgroundColor: colorScheme.outlineVariant,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The timer bar's spoken value: the whole seconds left ("12 seconds").
String timeLeftWords(Animation<double> chrono) {
  final controller = chrono is AnimationController ? chrono : null;
  final total = controller?.duration;
  if (total == null || total == Duration.zero) return '';
  final left = (total.inMilliseconds * (1 - chrono.value) / 1000).ceil();
  return left == 1 ? '1 second' : '$left seconds';
}

/// The answer being typed. The feedback flash/motion (rule 14: never colour
/// alone) applies here, not to the whole screen (`doc/design.md`: "flash
/// [...] on the input field").
class _AnswerDisplay extends StatelessWidget {
  const _AnswerDisplay({
    super.key,
    this.alignRight = false,
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

  /// Under a stacked question: the digits on its units column.
  final bool alignRight;

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
      child: Text(
        groupedDigits(typedDigits),
        textAlign: alignRight ? TextAlign.right : TextAlign.center,
        style: style,
        softWrap: false,
      ),
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
