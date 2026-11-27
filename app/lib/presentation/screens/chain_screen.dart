import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/challenges/chain.dart';
import '../../composition_root.dart';
import '../../core/state/chain_controller.dart';
import '../kit/kit.dart';
import '../strings/strings.dart';
import '../kit/numeric_keypad.dart';
import '../theme/app_theme.dart';

/// Builds a chain from a fresh seed and plays it full screen, over the
/// tabs; Play again builds the next one in place.
Future<void> playChain(
  BuildContext context,
  AppEnvironment environment, {
  required int secondsPerScreen,
  required int operations,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ChainFlowScreen(
      environment: environment,
      secondsPerScreen: secondsPerScreen,
      operations: operations,
    ),
  ),
);

/// Owns the round's controller; Play again swaps in a new one.
class ChainFlowScreen extends StatefulWidget {
  const ChainFlowScreen({
    super.key,
    required this.environment,
    required this.secondsPerScreen,
    required this.operations,
    this.seed,
  });

  final AppEnvironment environment;
  final int secondsPerScreen;
  final int operations;

  /// Tests pass one; the app uses the clock.
  final int? seed;

  @override
  State<ChainFlowScreen> createState() => _ChainFlowScreenState();
}

class _ChainFlowScreenState extends State<ChainFlowScreen> {
  late ChainController _controller = _build(widget.seed);

  ChainController _build(int? seed) => ChainController(
    chain: generateChain(
      seed: seed ?? DateTime.now().millisecondsSinceEpoch,
      operations: widget.operations,
    ),
    secondsPerScreen: widget.secondsPerScreen,
    statsStore: widget.environment.challengeStatsStore,
  )..start();

  void _playAgain() {
    final previous = _controller;
    setState(() => _controller = _build(null));
    previous.dispose();
  }

  Future<void> _confirmQuit() async {
    if (_controller.phase == ChainPhase.done) {
      Navigator.of(context).pop();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.game.quitTitle),
        actions: [
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: strings.common.cancel,
          ),
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: strings.common.quit,
          ),
        ],
      ),
    );
    if (quit == true && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PopScope(
      canPop: _controller.phase == ChainPhase.done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: SafeArea(
          child: ChainScreen(
            key: ObjectKey(_controller),
            controller: _controller,
            onQuit: _confirmQuit,
            onPlayAgain: _playAgain,
            onHome: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    ),
  );
}

/// Mockup 6: ✕ and `n / N`, a progress bar, one big operation per screen;
/// then the keypad; then the correction — the whole chain.
class ChainScreen extends StatefulWidget {
  const ChainScreen({
    super.key,
    required this.controller,
    required this.onQuit,
    required this.onPlayAgain,
    required this.onHome,
  });

  final ChainController controller;
  final VoidCallback onQuit;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  State<ChainScreen> createState() => _ChainScreenState();
}

class _ChainScreenState extends State<ChainScreen> {
  String _typed = '';

  static const _maxDigits = 3; // every value is at most 999

  void _digit(String d) {
    if (widget.controller.phase != ChainPhase.answering) return;
    if (_typed.length >= _maxDigits) return;
    setState(() => _typed += d);
  }

  void _backspace() {
    if (_typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _submit() {
    final value = int.tryParse(_typed);
    if (value == null) return;
    widget.controller.submit(value);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final digit = physicalDigitKeys[event.physicalKey];
    if (digit != null) {
      _digit(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final phase = controller.phase;
    final n = controller.operations;
    final shown = phase == ChainPhase.answering || phase == ChainPhase.done
        ? n
        : controller.screen;
    if (phase == ChainPhase.done) {
      return _ChainCorrection(
        controller: controller,
        onPlayAgain: widget.onPlayAgain,
        onHome: widget.onHome,
      );
    }
    final big = theme.textTheme.displayLarge?.digits;
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        children: [
          Padding(
            padding: metrics.rootPadding.copyWith(top: 8, bottom: 0),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurface,
                      ),
                      tooltip: strings.common.quit,
                      onPressed: widget.onQuit,
                    ),
                    const Spacer(),
                    Text(
                      '$shown / $n',
                      style: theme.textTheme.bodyLarge?.digits.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: shown / n,
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: switch (phase) {
                  ChainPhase.showing => Text(
                    controller.screen == 0
                        ? '${controller.chain.start}'
                        : '${controller.chain.steps[controller.screen - 1]}',
                    key: ValueKey('chain-screen-${controller.screen}'),
                    style: big,
                  ),
                  ChainPhase.blank => const SizedBox.shrink(),
                  ChainPhase.answering || ChainPhase.done => Container(
                    constraints: const BoxConstraints(minWidth: 140),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      _typed,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                },
              ),
            ),
          ),
          if (phase == ChainPhase.answering)
            Padding(
              padding: EdgeInsets.fromLTRB(
                metrics.rootPadding.left - metrics.keyGap,
                0,
                metrics.rootPadding.right - metrics.keyGap,
                metrics.rootPadding.bottom - metrics.keyGap,
              ),
              child: SizedBox(
                height: metrics.keypadHeight,
                child: NumericKeypad(
                  onDigit: _digit,
                  onBackspace: _backspace,
                  onValidate: _submit,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The result and the whole chain, line by line; Play again or Home.
class _ChainCorrection extends StatelessWidget {
  const _ChainCorrection({
    required this.controller,
    required this.onPlayAgain,
    required this.onHome,
  });

  final ChainController controller;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final chain = controller.chain;
    final values = chain.values;
    final muted = theme.extension<AppPalette>()!.textMuted;
    final line = theme.textTheme.titleMedium?.digits;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  controller.solved ? Icons.check_circle : Icons.cancel,
                  size: 40,
                  color: controller.solved
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  semanticLabel: controller.solved
                      ? strings.game.solved
                      : strings.game.missed,
                ),
                const SizedBox(height: 8),
                // The answer; a wrong one struck through beside it (never the
                // colour or the icon alone, rule 14).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${chain.answer}',
                      style: theme.textTheme.displaySmall?.digits,
                    ),
                    if (!controller.solved) ...[
                      const SizedBox(width: 16),
                      Text(
                        '${controller.given}',
                        semanticsLabel: strings.game.yourAnswer(
                          controller.given!,
                        ),
                        style: theme.textTheme.titleLarge?.digits.copyWith(
                          color: muted,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '${chain.start}',
                  textAlign: TextAlign.center,
                  style: line,
                ),
                for (final (i, step) in chain.steps.indexed)
                  Text(
                    '$step = ${values[i + 1]}',
                    textAlign: TextAlign.center,
                    style: line,
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: metrics.rootPadding.copyWith(top: 8),
          child: SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                AppButton.secondary(
                  onPressed: onHome,
                  label: strings.game.home,
                ),
                AppButton.primary(
                  onPressed: onPlayAgain,
                  label: strings.game.playAgain,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
