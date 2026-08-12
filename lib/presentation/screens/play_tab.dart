import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/models/exercise_type.dart';
import '../exercise_type_labels.dart';
import '../theme/app_theme.dart';
import 'session_flow_screen.dart';

/// 2 types par défaut, pas 4 : avec `n_min` (4 depuis l'étape 4.2, 8
/// jusque-là) et le plafond de session, c'est ce qui garantit une couverture
/// du cache de niveau dès la première session pour un joueur qui ne touche
/// pas à la sélection (étape 4.1, commit A — voir `doc/decisions.md`).
/// Addition/soustraction : opérations inverses l'une de l'autre, charge
/// cognitive minimale pour un premier joueur ; les 5 autres types restent
/// tous disponibles, juste décochés.
const _defaultSelectedTypes = {ExerciseType.addition, ExerciseType.subtraction};

/// Onglet « Jouer » de `AppShell`. Ne gère plus que la sélection des types :
/// la session elle-même est poussée en plein écran par-dessus la barre
/// d'onglets (`SessionFlowScreen`), pas basculée inline comme avant l'étape
/// 5, commit E.
class PlayTab extends StatefulWidget {
  const PlayTab({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  Set<ExerciseType> _selectedTypes = {..._defaultSelectedTypes};
  bool _isStarting = false;
  String? _startError;

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
      _startError = null;
    });
    try {
      final controller = await buildSessionController(widget.environment, _selectedTypes);
      if (!mounted) return;
      controller.start();
      setState(() => _isStarting = false);
      // SessionFlowScreen possède désormais le contrôleur (dispose() dans
      // son propre State) : pas besoin d'attendre le retour de la route ici.
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SessionFlowScreen(controller: controller, environment: widget.environment),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // Le bouton "Commencer" redevient actif : c'est l'action de reprise,
      // pas besoin d'un bouton dédié.
      setState(() {
        _isStarting = false;
        // Pas de « Réessayez. » : le bouton Commencer, redevenu actif, porte
        // déjà l'action (`doc/design.md` — un message d'erreur ne contient
        // pas l'action).
        _startError = 'Impossible de démarrer la session.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TypeSelectionView(
      selectedTypes: _selectedTypes,
      onChanged: (types) => setState(() => _selectedTypes = types),
      onStart: _selectedTypes.isEmpty || _isStarting ? null : _startSession,
      isStarting: _isStarting,
      startError: _startError,
    );
  }
}

class _TypeSelectionView extends StatelessWidget {
  const _TypeSelectionView({
    required this.selectedTypes,
    required this.onChanged,
    required this.onStart,
    required this.isStarting,
    required this.startError,
  });

  final Set<ExerciseType> selectedTypes;
  final ValueChanged<Set<ExerciseType>> onChanged;
  final VoidCallback? onStart;
  final bool isStarting;
  final String? startError;

  void _toggle(ExerciseType type, bool selected) {
    final updated = Set<ExerciseType>.of(selectedTypes);
    if (selected) {
      updated.add(type);
    } else {
      updated.remove(type);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: theme.extension<AppMetrics>()!.rootPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Math Trainer', style: theme.textTheme.titleMedium),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final type in ExerciseType.values)
                  FilterChip(
                    label: Text(exerciseTypeLabel(type)),
                    selected: selectedTypes.contains(type),
                    onSelected: (selected) => _toggle(type, selected),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onStart,
              child: isStarting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Commencer'),
            ),
            if (selectedTypes.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Aucun type sélectionné.', style: theme.textTheme.bodyMedium),
            ] else if (startError != null) ...[
              const SizedBox(height: 8),
              Text(
                startError!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
