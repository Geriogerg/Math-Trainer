import 'package:material_ui/material_ui.dart';

import 'package:math_core/challenges/count.dart';
import '../../composition_root.dart';
import '../../core/state/count_controller.dart';
import '../../core/state/hints.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';

/// Plays a Get-the-count round full screen, over the tabs — its rules
/// first, on the first open (Phase 6b commit 4, review m17).
Future<void> playCount(BuildContext context, AppEnvironment environment) async {
  final hints = environment.hints;
  if (hints != null && !await hints.seen(Hint.countRules)) {
    if (!context.mounted) return;
    await showRules(
      context,
      title: 'Get the count',
      lines: const [
        'Reach the target with the numbers given and + − × ÷, each number '
            'once at most.',
        'The closer, the better; reaching it ends the round.',
        'Practice: it never moves your levels.',
      ],
      confirm: null,
    );
    await hints.markSeen(Hint.countRules);
  }
  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CountFlowScreen(environment: environment),
    ),
  );
}

/// Owns the round's controller; Play again swaps in a new one.
class CountFlowScreen extends StatefulWidget {
  const CountFlowScreen({super.key, required this.environment, this.seed});

  final AppEnvironment environment;

  /// Tests pass one; the app uses the clock.
  final int? seed;

  @override
  State<CountFlowScreen> createState() => _CountFlowScreenState();
}

class _CountFlowScreenState extends State<CountFlowScreen> {
  late CountController _controller = _build(widget.seed);

  CountController _build(int? seed) => CountController(
    seed: seed ?? DateTime.now().millisecondsSinceEpoch,
    statsStore: widget.environment.challengeStatsStore,
  )..start();

  void _playAgain() {
    final previous = _controller;
    setState(() => _controller = _build(null));
    previous.dispose();
  }

  Future<void> _confirmQuit() async {
    if (_controller.ended) {
      Navigator.of(context).pop();
      return;
    }
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quit the game?'),
        actions: [
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: 'Cancel',
          ),
          AppButton.secondary(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: 'Quit',
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
      canPop: _controller.ended,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: SafeArea(
          child: CountScreen(
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

/// Mockup 5: ✕ and the time left, its bar, the target, six tiles, the four
/// operators, undo and reset. Then the correction.
class CountScreen extends StatelessWidget {
  const CountScreen({
    super.key,
    required this.controller,
    required this.onQuit,
    required this.onPlayAgain,
    required this.onHome,
    this.header,
    this.progressLabel,
  });

  final CountController controller;
  final VoidCallback onQuit;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  /// Above the timer bar: a duel's lanes (Phase 7).
  final Widget? header;

  /// Top right instead of the clock: a duel's round ("2 / 3").
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    if (controller.ended) {
      return _CountCorrection(
        controller: controller,
        onPlayAgain: onPlayAgain,
        onHome: onHome,
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final left = controller.remainingSeconds;
    final clock = '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    final tiles = controller.board.tiles;
    return SingleChildScrollView(
      padding: metrics.rootPadding.copyWith(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close, color: scheme.onSurface),
                tooltip: 'Quit',
                onPressed: onQuit,
              ),
              const Spacer(),
              Text(
                progressLabel ?? clock,
                style: theme.textTheme.bodyLarge?.digits.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (header case final header?) ...[const SizedBox(height: 4), header],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: left / controller.roundSeconds,
              minHeight: 5,
              backgroundColor: scheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '${controller.puzzle.target}',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.digits,
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: metrics.keyGap * 2,
            crossAxisSpacing: metrics.keyGap * 2,
            childAspectRatio: 2,
            children: [
              for (final tile in tiles)
                _Tile(
                  key: ValueKey('count-tile-${tile.id}'),
                  tile: tile,
                  picked: controller.first == tile.id,
                  onTap: () => controller.tapTile(tile.id),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              for (final (i, op) in CountOperator.values.indexed) ...[
                if (i > 0) SizedBox(width: metrics.keyGap * 2),
                Expanded(
                  child: _Key(
                    label: op.symbol,
                    selected: controller.operator == op,
                    onTap: controller.first == null
                        ? null
                        : () => controller.tapOperator(op),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: metrics.keyGap * 2),
          Row(
            children: [
              Expanded(
                child: _Key(
                  icon: Icons.undo,
                  semanticLabel: 'Undo',
                  onTap: controller.board.canUndo ? controller.undo : null,
                ),
              ),
              SizedBox(width: metrics.keyGap * 2),
              Expanded(
                child: _Key(
                  icon: Icons.refresh,
                  semanticLabel: 'Reset',
                  onTap: controller.board.canUndo ? controller.reset : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A number on the board. Picked: the accent outline, thicker (rule 14);
/// used: faded and inert.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.tile,
    required this.picked,
    required this.onTap,
  });

  final CountTile tile;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(
      theme.extension<AppMetrics>()!.radius * 0.75,
    );
    return Opacity(
      opacity: tile.used ? 0.25 : 1,
      child: Semantics(
        button: !tile.used,
        selected: picked,
        child: Material(
          color: picked
              ? scheme.primary.withValues(alpha: 0.14)
              : scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: picked ? scheme.primary : scheme.outline,
              width: picked ? 2.5 : 1.5,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: tile.used ? null : onTap,
            child: Center(
              child: Text(
                '${tile.value}',
                style: theme.textTheme.titleLarge?.digits,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An operator, undo or reset — keypad-like keys, 52 high.
class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    this.selected = false,
    required this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final metrics = theme.extension<AppMetrics>()!;
    final radius = BorderRadius.circular(metrics.radius * 0.75);
    final foreground = selected
        ? scheme.onPrimary
        : (icon != null ? scheme.onSurfaceVariant : scheme.onSurface);
    return Semantics(
      selected: selected,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: metrics.controlHeight,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: foreground, semanticLabel: semanticLabel)
                  : Text(
                      label!,
                      style: theme.textTheme.titleLarge?.digits.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Solved (with the time) or not (the closest value), then the shortest
/// solution; Play again or Home.
class _CountCorrection extends StatelessWidget {
  const _CountCorrection({
    required this.controller,
    required this.onPlayAgain,
    required this.onHome,
  });

  final CountController controller;
  final VoidCallback onPlayAgain;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final line = theme.textTheme.titleMedium?.digits;
    final solved = controller.solved;
    final elapsed = controller.elapsedMs;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  solved ? Icons.check_circle : Icons.cancel,
                  size: 40,
                  color: solved
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                  semanticLabel: solved ? 'Solved' : 'Missed',
                ),
                const SizedBox(height: 8),
                Text(
                  '${controller.puzzle.target}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.digits,
                ),
                const SizedBox(height: 16),
                Center(
                  child: solved && elapsed != null
                      ? StatTile(
                          value: '${(elapsed / 1000).toStringAsFixed(1)} s',
                          label: 'Time',
                        )
                      : StatTile(
                          value: '${controller.board.closest}',
                          label: 'Closest',
                        ),
                ),
                const SizedBox(height: 24),
                for (final step in controller.solution)
                  Text('$step', textAlign: TextAlign.center, style: line),
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
                AppButton.secondary(onPressed: onHome, label: 'Home'),
                AppButton.primary(onPressed: onPlayAgain, label: 'Play again'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
