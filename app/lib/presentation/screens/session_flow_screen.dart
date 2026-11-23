import 'package:material_ui/material_ui.dart';

import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/level_cache_entry.dart';

import '../kit/kit.dart';

import '../../composition_root.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'empty_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';
import 'tips_view.dart';

/// Starts [controller] and shows it full screen over the tabs; resolves
/// once the player has left and the end-of-session write is done — the
/// caller can then re-read levels and history.
///
/// [setup]: what Play again replays with. [playAgain], when given, builds
/// the next controller instead (Tables mode); [onFinished] is told each
/// controller played to its last question, once. [showMethods]: a Method
/// under each mistake on the result (Basics and Advanced games; not Tables
/// mode — `doc/levels.md` section 9).
Future<void> playSessionFlow(
  BuildContext context,
  AppEnvironment environment,
  SessionController controller, {
  GameSetup? setup,
  SessionController Function()? playAgain,
  void Function(SessionController controller)? onFinished,
  bool showMethods = true,
}) async {
  controller.start();
  // SessionFlowScreen owns the controller (dispose() in its own State).
  // The route returns the end-of-session write still running
  // (`_exitToSelection`): re-reading before it completes would show the
  // levels from before the game.
  final pendingPersistence = await Navigator.of(context).push<Future<void>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SessionFlowScreen(
        controller: controller,
        environment: environment,
        setup: setup,
        playAgain: playAgain,
        onFinished: onFinished,
        showMethods: showMethods,
      ),
    ),
  );
  await pendingPersistence;
  // The session is stored: send it (and anything still pending) in the
  // background — offline, it waits in the queue.
  environment.uploadQueue?.flush().ignore();
}

/// Pushed full screen over the tabbed shell (`doc/design.md`: "the session
/// screen [...] carries no navigation"). Switches between `SessionScreen`
/// and `ResultScreen` according to `SessionController.state.status`.
///
/// Owns the controller shown (not just a relay of the one received as a
/// parameter): an immediate replay (step 4.2, commit C) builds a new one and
/// swaps it for the old one without popping the route.
class SessionFlowScreen extends StatefulWidget {
  const SessionFlowScreen({
    super.key,
    required this.controller,
    required this.environment,
    this.setup,
    this.playAgain,
    this.onFinished,
    this.showMethods = false,
  });

  final SessionController controller;
  final AppEnvironment environment;

  /// The game's setup, kept for Play again.
  final GameSetup? setup;

  /// Builds Play again's controller instead of a game (Tables mode).
  final SessionController Function()? playAgain;

  /// Told each controller played to its last question, once.
  final void Function(SessionController controller)? onFinished;

  /// A Method under each mistake on the result screen.
  final bool showMethods;

  @override
  State<SessionFlowScreen> createState() => _SessionFlowScreenState();
}

class _SessionFlowScreenState extends State<SessionFlowScreen> {
  late SessionController _controller;
  bool _isRestarting = false;
  String? _restartError;

  /// The controllers already reported to `onFinished`.
  final _reported = <SessionController>{};

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_reportFinished);
  }

  @override
  void dispose() {
    _controller.removeListener(_reportFinished);
    _controller.dispose();
    super.dispose();
  }

  void _reportFinished() {
    final controller = _controller;
    if (controller.state.status == SessionStatus.finished &&
        _reported.add(controller)) {
      widget.onFinished?.call(controller);
    }
  }

  /// Returns the running end-of-session write to `PlayTab`, which waits for
  /// it before re-reading the overall level shown.
  void _exitToSelection() =>
      Navigator.of(context).pop(_controller.pendingPersistence);

  /// Back gesture during a running session (step 5, commit A): the pop is
  /// intercepted (`canPop: false` while `inProgress`), confirmed, then
  /// handled as a manual abandonment — same finished/interrupted
  /// distinction as the automatic abandonment on timeouts (step 4.2).
  Future<void> _handlePopAttempt(bool didPop) async {
    if (didPop) return;
    await _confirmQuit();
  }

  /// The ✕ and the back gesture alike (Redesign phase). Labels only: a game
  /// quit early is kept as interrupted, which moves no level.
  Future<void> _confirmQuit() async {
    if (_controller.state.status != SessionStatus.inProgress) return;
    final confirmed = await showDialog<bool>(
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
    if (confirmed != true) return;
    _controller.abandon();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// "More tips" under a Method: the Tips page over the result, at [type]'s
  /// section, the player's bands marked from their current levels.
  Future<void> _openTips(ExerciseType type) async {
    final environment = widget.environment;
    Map<ExerciseType, LevelCacheEntry> levels;
    try {
      await _controller.pendingPersistence;
      levels = await environment.repository.currentLevels(environment.playerId);
    } on Exception catch (_) {
      // The bands then fall back to the game's frozen levels.
      levels = const {};
    }
    if (!mounted) return;
    final frozen = _controller.config.levels;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: TipsView(
              focus: type,
              levelOf: (t) => levels[t]?.level ?? frozen[t] ?? Level.zero,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  /// Same types, levels re-read (so up to date), new seed — reusing it would
  /// replay exactly the same questions (`doc/decisions.md`).
  Future<void> _playAgain() async {
    setState(() {
      _isRestarting = true;
      _restartError = null;
    });
    try {
      // The level cache update of the session that just ended runs in the
      // background: without waiting for it, we would re-read stale levels,
      // the opposite of what the immediate replay promises.
      await _controller.pendingPersistence;
      final types = _controller.config.enabledTypes;
      final next =
          widget.playAgain?.call() ??
          await buildSessionController(
            widget.environment,
            types,
            setup: widget.setup,
          );
      if (!mounted) return;
      next
        ..addListener(_reportFinished)
        ..start();
      final previous = _controller;
      setState(() {
        _controller = next;
        _isRestarting = false;
      });
      previous
        ..removeListener(_reportFinished)
        ..dispose();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRestarting = false;
        // No "Try again.": the Play again button, active again, already
        // carries the action (`doc/design.md`).
        _restartError = 'Could not start a new session.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final status = _controller.state.status;
        return PopScope(
          canPop: status != SessionStatus.inProgress,
          onPopInvokedWithResult: (didPop, result) => _handlePopAttempt(didPop),
          child: Scaffold(
            body: SafeArea(
              child: switch (status) {
                SessionStatus.notStarted => EmptyState(
                  message: 'Session not started.',
                  actionLabel: 'Quit',
                  onAction: () => Navigator.of(context).maybePop(),
                ),
                SessionStatus.inProgress => SessionScreen(
                  controller: _controller,
                  effects: widget.environment.sessionEffects,
                  onQuit: _confirmQuit,
                ),
                SessionStatus.finished ||
                SessionStatus.interrupted => ResultScreen(
                  controller: _controller,
                  onPlayAgain: _playAgain,
                  onExitToSelection: _exitToSelection,
                  isRestarting: _isRestarting,
                  restartError: _restartError,
                  effects: widget.environment.sessionEffects,
                  showMethods: widget.showMethods,
                  onMoreTips: _openTips,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}
