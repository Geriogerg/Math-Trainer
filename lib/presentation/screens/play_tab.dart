import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/state/session_controller.dart';
import '../exercise_type_labels.dart';
import '../../core/domain/leveling/overall_level.dart';
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
  const PlayTab({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;

  /// Bouton nuit/jour, dans le coin de l'écran d'accueil (`doc/design.md`) —
  /// `null` par défaut pour ne pas casser les tests qui ne s'intéressent pas
  /// au thème.
  final VoidCallback? onToggleTheme;

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  Set<ExerciseType> _selectedTypes = {..._defaultSelectedTypes};
  bool _isStarting = false;
  String? _startError;

  /// `null` tant que la lecture n'a pas résolu — le défaut ci-dessus reste
  /// affiché pendant ce court intervalle plutôt qu'un état de chargement sur
  /// l'écran principal (analyse UX post-étape 5 : lecture locale, pas de
  /// spinner justifié pour ça).
  double? _globalLevel;
  bool _hasHistory = false;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    // Purement auxiliaire (repère de niveau, accueil, sélection mémorisée) :
    // un échec ici ne doit jamais empêcher de lancer une session avec le
    // défaut déjà affiché — même logique que l'échec silencieux de
    // `_persistCompletedSession` côté contrôleur.
    try {
      final results = await Future.wait([
        widget.environment.typeSelectionStore.load(),
        widget.environment.repository.currentLevels(
          widget.environment.playerId,
        ),
      ]);
      if (!mounted) return;
      final storedSelection = results[0] as Set<ExerciseType>?;
      final levels = results[1] as Map<ExerciseType, LevelCacheEntry>;
      setState(() {
        if (storedSelection != null) _selectedTypes = storedSelection;
        _hasHistory = levels.isNotEmpty;
        _globalLevel = levels.isEmpty ? null : overallLevel(levels);
      });
    } on Exception catch (_) {
      // Reste sur le défaut déjà affiché — pas d'état d'erreur sur l'écran
      // principal pour une information secondaire.
    }
  }

  void _updateSelection(Set<ExerciseType> types) {
    setState(() => _selectedTypes = types);
    // Écriture continue, pas de bouton dédié — en tâche de fond, l'échec
    // silencieux ne coûte qu'un retour au défaut au prochain lancement.
    widget.environment.typeSelectionStore.save(types).ignore();
  }

  Future<void> _startSession() async {
    setState(() {
      _isStarting = true;
      _startError = null;
    });
    final SessionController controller;
    try {
      controller = await buildSessionController(
        widget.environment,
        _selectedTypes,
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
      return;
    }
    if (!mounted) return;
    controller.start();
    setState(() => _isStarting = false);
    // SessionFlowScreen possède le contrôleur (dispose() dans son propre
    // State). La route rend l'écriture de fin de session encore en cours
    // (`SessionFlowScreen._exitToSelection`) : relire les niveaux avant
    // qu'elle aboutisse afficherait le niveau global d'avant la partie.
    final pendingPersistence = await Navigator.of(context)
        .push<Future<void>>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => SessionFlowScreen(
              controller: controller,
              environment: widget.environment,
            ),
          ),
        );
    await pendingPersistence;
    if (mounted) await _loadStartupState();
  }

  @override
  Widget build(BuildContext context) {
    return _TypeSelectionView(
      selectedTypes: _selectedTypes,
      onChanged: _updateSelection,
      onStart: _selectedTypes.isEmpty || _isStarting ? null : _startSession,
      isStarting: _isStarting,
      startError: _startError,
      hasHistory: _hasHistory,
      globalLevel: _globalLevel,
      onToggleTheme: widget.onToggleTheme,
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
    required this.hasHistory,
    required this.globalLevel,
    required this.onToggleTheme,
  });

  final Set<ExerciseType> selectedTypes;
  final ValueChanged<Set<ExerciseType>> onChanged;
  final VoidCallback? onStart;
  final bool isStarting;
  final String? startError;
  final VoidCallback? onToggleTheme;

  /// Historique existant pour ce joueur (au moins un type déjà joué) —
  /// distingue le repère de niveau de la phrase d'accueil pour un nouveau
  /// joueur (analyse UX post-étape 5).
  final bool hasHistory;
  final double? globalLevel;

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
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: theme.extension<AppMetrics>()!.rootPadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Math Trainer', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  hasHistory
                      ? 'Niveau global : ${globalLevel?.round() ?? '—'}'
                      : 'La difficulté s\'ajuste à tes réponses.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.extension<AppPalette>()!.textMuted,
                  ),
                ),
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
                  Text(
                    'Aucun type sélectionné.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else if (startError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    startError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: isDark ? 'Mode clair' : 'Mode sombre',
            onPressed: onToggleTheme,
          ),
        ),
      ],
    );
  }
}
