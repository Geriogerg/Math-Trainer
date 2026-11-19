import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../../core/domain/models/exercise_type.dart';
import '../../core/domain/persistence/level_cache_entry.dart';
import '../../core/state/session_controller.dart';
import '../exercise_type_labels.dart';
import '../../core/domain/leveling/overall_level.dart';
import '../theme/app_theme.dart';
import 'session_flow_screen.dart';

/// 2 types by default, not 4: with `n_min` (4 since step 4.2, 8 before) and
/// the session cap, this guarantees level cache coverage from the first
/// session for a player who never touches the selection (step 4.1, commit
/// A — see `doc/decisions.md`). Addition/subtraction: inverse operations,
/// minimal cognitive load for a first player; the 5 other types stay
/// available, just unticked.
const _defaultSelectedTypes = {ExerciseType.addition, ExerciseType.subtraction};

/// The "Play" tab of `AppShell`. Only handles the type selection: the
/// session itself is pushed full screen over the tab bar
/// (`SessionFlowScreen`), not switched inline as before step 5, commit E.
class PlayTab extends StatefulWidget {
  const PlayTab({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;

  /// Day/night button in the corner of the home screen (`doc/design.md`) —
  /// `null` by default so as not to break tests that do not care about the
  /// theme.
  final VoidCallback? onToggleTheme;

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  Set<ExerciseType> _selectedTypes = {..._defaultSelectedTypes};
  bool _isStarting = false;
  String? _startError;

  /// `null` until the read resolves — the default above stays shown during
  /// this short interval rather than a loading state on the main screen
  /// (post-step-5 UX review: a local read, no spinner justified).
  double? _globalLevel;
  bool _hasHistory = false;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
  }

  Future<void> _loadStartupState() async {
    // Purely auxiliary (level hint, welcome, remembered selection): a
    // failure here must never prevent starting a session with the default
    // already shown — same logic as the silent failure of
    // `_persistCompletedSession` in the controller.
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
      // Stay on the default already shown — no error state on the main
      // screen for secondary information.
    }
  }

  void _updateSelection(Set<ExerciseType> types) {
    setState(() => _selectedTypes = types);
    // Continuous write, no dedicated button — in the background, a silent
    // failure only costs a return to the default at the next launch.
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
      // The "Start" button becomes active again: it is the retry action, no
      // need for a dedicated button.
      setState(() {
        _isStarting = false;
        // No "Try again.": the Start button, active again, already carries
        // the action (`doc/design.md` — an error message does not contain
        // the action).
        _startError = 'Could not start the session.';
      });
      return;
    }
    if (!mounted) return;
    controller.start();
    setState(() => _isStarting = false);
    // SessionFlowScreen owns the controller (dispose() in its own State).
    // The route returns the end-of-session write still running
    // (`SessionFlowScreen._exitToSelection`): re-reading the levels before it
    // completes would show the overall level from before the game.
    final pendingPersistence = await Navigator.of(context).push<Future<void>>(
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

  /// Existing history for this player (at least one type played) — tells
  /// the level hint apart from the welcome sentence for a new player
  /// (post-step-5 UX review).
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
                      ? 'Overall level: ${globalLevel?.round() ?? '—'}'
                      : 'Difficulty adapts to your answers.',
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
                      : const Text('Start'),
                ),
                if (selectedTypes.isEmpty) ...[
                  const SizedBox(height: 8),
                  Text('No type selected.', style: theme.textTheme.bodyMedium),
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
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            onPressed: onToggleTheme,
          ),
        ),
      ],
    );
  }
}
