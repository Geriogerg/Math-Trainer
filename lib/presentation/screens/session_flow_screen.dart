import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'empty_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';

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
  });

  final SessionController controller;
  final AppEnvironment environment;

  @override
  State<SessionFlowScreen> createState() => _SessionFlowScreenState();
}

class _SessionFlowScreenState extends State<SessionFlowScreen> {
  late SessionController _controller;
  bool _isRestarting = false;
  String? _restartError;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quit the game?'),
        content: const Text(
          'The session will be interrupted. Answers already given stay saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _controller.abandon();
    if (!mounted) return;
    Navigator.of(context).pop();
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
      final next = await buildSessionController(widget.environment, types);
      if (!mounted) return;
      next.start();
      final previous = _controller;
      setState(() {
        _controller = next;
        _isRestarting = false;
      });
      previous.dispose();
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
                ),
                SessionStatus.finished ||
                SessionStatus.interrupted => ResultScreen(
                  controller: _controller,
                  onPlayAgain: _playAgain,
                  onExitToSelection: _exitToSelection,
                  isRestarting: _isRestarting,
                  restartError: _restartError,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}
