import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'empty_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';

/// Poussée en plein écran par-dessus la coquille à onglets (`doc/design.md` :
/// « l'écran de session [...] ne porte aucune navigation »). Bascule entre
/// `SessionScreen` et `ResultScreen` selon `SessionController.state.status`.
///
/// Propriétaire du contrôleur affiché (pas juste un relais de celui reçu en
/// paramètre) : une relance immédiate (étape 4.2, commit C) en construit un
/// nouveau et le substitue à l'ancien sans dépiler la route.
class SessionFlowScreen extends StatefulWidget {
  const SessionFlowScreen({super.key, required this.controller, required this.environment});

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

  /// Rend l'écriture de fin de session en cours à `PlayTab`, qui l'attend
  /// avant de relire le niveau global affiché.
  void _exitToSelection() =>
      Navigator.of(context).pop(_controller.pendingPersistence);

  /// Geste retour pendant une session en cours (étape 5, commit A) : le
  /// pop est intercepté (`canPop: false` tant que `inProgress`), confirmé
  /// puis traité comme un abandon manuel — même distinction terminée/
  /// interrompue qu'un abandon automatique par timeouts (étape 4.2).
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

  /// Mêmes types, niveaux relus (donc à jour), nouvelle seed — la réutiliser
  /// ferait rejouer exactement les mêmes questions (`doc/decisions.md`).
  Future<void> _playAgain() async {
    setState(() {
      _isRestarting = true;
      _restartError = null;
    });
    try {
      // La mise à jour du cache de niveaux de la session qui vient de se
      // terminer tourne en tâche de fond : sans l'attendre, on relirait des
      // niveaux périmés, à l'inverse de ce que la relance immédiate promet.
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
        // Pas de « Réessayez. » : le bouton Rejouer, redevenu actif, porte
        // déjà l'action (`doc/design.md`).
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
                SessionStatus.inProgress => SessionScreen(controller: _controller),
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
