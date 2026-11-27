import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:math_core/duel/duel_client.dart';

import '../../composition_root.dart';
import '../../core/state/duel_controller.dart';
import '../kit/kit.dart';
import '../screens/count_screen.dart';
import '../screens/empty_state.dart';
import '../screens/session_screen.dart';
import 'duel_lanes.dart';
import 'duel_result_view.dart';
import 'duel_texts.dart';

/// Plays a duel full screen over the tabs: [load] gets the offer (find an
/// opponent, open a challenge…), then the duel, then its result; Rematch
/// plays the next one in place. Resolves when the player leaves.
Future<void> playDuel(
  BuildContext context,
  AppEnvironment environment,
  Future<DuelOffer> Function() load,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => DuelFlowScreen(environment: environment, load: load),
  ),
);

class DuelFlowScreen extends StatefulWidget {
  const DuelFlowScreen({
    super.key,
    required this.environment,
    required this.load,
    this.clock = DateTime.now,
  });

  final AppEnvironment environment;
  final Future<DuelOffer> Function() load;

  /// Tests pass their own (answer times, lanes).
  final DateTime Function() clock;

  /// How long waking the server may take before the screen explains the
  /// wait (Phase 6b commit 5).
  static const slowWakeAfter = Duration(seconds: 3);

  @override
  State<DuelFlowScreen> createState() => _DuelFlowScreenState();
}

class _DuelFlowScreenState extends State<DuelFlowScreen> {
  DuelController? _controller;

  /// Why no duel could start; `null` while loading or playing.
  String? _problem;

  /// Before a duel (Phase 6b commit 5, review M15): first the server is
  /// woken — nothing asked yet, so Cancel is safe — then asked for the
  /// duel, a short request with no Cancel: the server may already have
  /// made the duel, and one left for 24 hours is a loss.
  bool _waking = false;

  /// The wake has taken more than a moment: the screen says why.
  bool _slowWake = false;
  Timer? _slowWakeTimer;

  @override
  void initState() {
    super.initState();
    _start(widget.load);
  }

  Future<void> _start(Future<DuelOffer> Function() load) async {
    final previous = _controller;
    _slowWakeTimer?.cancel();
    _slowWakeTimer = Timer(DuelFlowScreen.slowWakeAfter, () {
      if (mounted) setState(() => _slowWake = true);
    });
    setState(() {
      _controller = null;
      _problem = null;
      _waking = true;
      _slowWake = false;
    });
    previous?.dispose();
    try {
      // A free host sleeps and takes up to a minute to wake: `/health`
      // first. Left meanwhile (Cancel): nothing was asked.
      await widget.environment.duelClient?.support();
      _slowWakeTimer?.cancel();
      if (!mounted) return;
      setState(() => _waking = false);
      final offer = await load();
      if (!mounted) return;
      setState(
        () => _controller = buildDuelController(
          widget.environment,
          offer,
          clock: widget.clock,
        )..start(),
      );
    } on DuelAccountRequired {
      _fail('Save your progress to play online.');
    } on DuelRefused catch (e) {
      _fail(switch (e.reason) {
        'exists' => 'A challenge is already open.',
        'notLinked' => 'This player cannot be challenged.',
        _ => 'This duel is not available.',
      });
    } on Exception catch (_) {
      _fail('Could not reach the server.');
    }
  }

  void _fail(String problem) {
    _slowWakeTimer?.cancel();
    if (mounted) setState(() => _problem = problem);
  }

  Future<void> _confirmQuit(DuelController controller) async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quit the duel?'),
        content: const Text('It still counts.'),
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
    if (quit == true) controller.quit();
  }

  void _rematch(DuelController controller) {
    final client = widget.environment.duelClient;
    if (client == null) return;
    final offer = controller.offer;
    _start(() => client.find(offer.mode, rematchOf: offer.duelId));
  }

  @override
  void dispose() {
    _slowWakeTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final problem = _problem;
    return PopScope(
      // The ✕ and its confirmation are the only way out of a duel in play.
      canPop: controller == null || controller.phase != DuelPhase.playing,
      child: Scaffold(
        body: SafeArea(
          child: problem != null
              ? EmptyState(
                  message: problem,
                  actionLabel: 'Close',
                  onAction: () => Navigator.of(context).pop(),
                )
              : controller == null
              ? _Finding(
                  waking: _waking && _slowWake,
                  onCancel: _waking ? () => Navigator.of(context).pop() : null,
                )
              : ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => _body(context, controller),
                ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, DuelController controller) {
    if (controller.phase != DuelPhase.playing) {
      return DuelResultView(
        controller: controller,
        onOnline: () => Navigator.of(context).pop(),
        // A challenger waits for their friend: nothing to rematch yet.
        onRematch: controller.offer.lane == null
            ? null
            : () => _rematch(controller),
      );
    }
    final lanes = DuelLanes(
      mine: controller.mine,
      theirs: controller.theirs,
      opponentName: opponentLabel(controller.offer),
    );
    if (controller.quiz case final quiz?) {
      return SessionScreen(
        controller: quiz,
        effects: widget.environment.sessionEffects,
        onQuit: () => _confirmQuit(controller),
        header: lanes,
      );
    }
    final round = controller.round;
    if (round == null) return const _Finding();
    return CountScreen(
      key: ValueKey('duel-round-${controller.roundIndex}'),
      controller: round,
      onQuit: () => _confirmQuit(controller),
      onPlayAgain: () {},
      onHome: () {},
      header: lanes,
      progressLabel: '${controller.roundIndex + 1} / 3',
    );
  }
}

class _Finding extends StatelessWidget {
  const _Finding({this.waking = false, this.onCancel});

  /// The server is still waking: said, with how long it can take.
  final bool waking;

  /// Cancel while nothing has been asked yet; `null`: hidden.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            waking ? 'Waking the server…' : 'Finding an opponent…',
            style: theme.textTheme.bodyLarge,
          ),
          if (waking) const Caption('It can take up to a minute.'),
          if (onCancel case final cancel?) ...[
            const SizedBox(height: 16),
            AppButton.secondary(label: 'Cancel', onPressed: cancel),
          ],
        ],
      ),
    );
  }
}
