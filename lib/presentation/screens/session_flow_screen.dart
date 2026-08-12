import 'package:flutter/material.dart';

import '../../core/state/session_controller.dart';
import '../../core/state/session_state.dart';
import 'result_screen.dart';
import 'session_screen.dart';

/// Poussée en plein écran par-dessus la coquille à onglets (`doc/design.md` :
/// « l'écran de session [...] ne porte aucune navigation »). Bascule entre
/// `SessionScreen` et `ResultScreen` selon `SessionController.state.status` —
/// logique reprise telle quelle de l'ancien `HomeScreen`, qui la faisait
/// inline au lieu de la pousser sur une route dédiée.
class SessionFlowScreen extends StatefulWidget {
  const SessionFlowScreen({super.key, required this.controller});

  final SessionController controller;

  @override
  State<SessionFlowScreen> createState() => _SessionFlowScreenState();
}

class _SessionFlowScreenState extends State<SessionFlowScreen> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  void _restart() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            return switch (widget.controller.state.status) {
              // N'arrive jamais en pratique : start() est appelé avant de
              // pousser cette route. Géré quand même pour l'exhaustivité du
              // switch (règle 11).
              SessionStatus.notStarted => const SizedBox.shrink(),
              SessionStatus.inProgress => SessionScreen(controller: widget.controller),
              SessionStatus.finished ||
              SessionStatus.interrupted => ResultScreen(
                controller: widget.controller,
                onRestart: _restart,
              ),
            };
          },
        ),
      ),
    );
  }
}
