import 'package:material_ui/material_ui.dart';

import 'package:math_core/challenges/chain.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/main_level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import '../../composition_root.dart';
import '../../core/state/session_controller.dart';
import '../exercise_type_labels.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';
import 'chain_screen.dart';
import 'count_screen.dart';
import 'session_flow_screen.dart';

/// Addition and subtraction ticked for a player who never chose: inverse
/// operations, the lightest start (step 4.1, `doc/decisions.md`).
const _defaultSelectedTypes = {ExerciseType.addition, ExerciseType.subtraction};

/// Stable handles for tests on the Home rows' Play buttons.
ValueKey<String> playButtonKey(ExerciseFamily family) =>
    ValueKey('play-${family.name}');

/// The Play tab (Redesign phase, mockups 1 and 2): Home — the main level,
/// a row per family with its Play button, the challenges — and, after Play,
/// the setup page of that row's selection. Both keep the bottom bar; the
/// game itself is pushed full screen (`SessionFlowScreen`). A new player
/// is first offered the placement test (Phase 1).
class PlayTab extends StatefulWidget {
  const PlayTab({super.key, required this.environment, this.isActive = true});

  final AppEnvironment environment;

  /// True when `AppShell` shows this tab. Coming back to it re-reads the
  /// startup state: a placement taken from Profile ends the offer here.
  final bool isActive;

  @override
  State<PlayTab> createState() => _PlayTabState();
}

class _PlayTabState extends State<PlayTab> {
  /// Both rows' selections in one set (one store): each row reads its own
  /// family out of it.
  Set<ExerciseType> _selectedTypes = {..._defaultSelectedTypes};
  GameSetup _setup = GameSetup();

  /// The row whose setup page is open; `null`: Home.
  ExerciseFamily? _setupFamily;

  /// The chain's setup page is open (Redesign phase commit 7).
  bool _chainSetupOpen = false;

  /// Its choices, remembered (`ChainSetupStore`, Redesign close-out).
  ChainSetup _chainSetup = ChainSetup();

  bool _isStarting = false;
  String? _startError;

  /// `null` until read, or if the read failed (levels then show as 0).
  Map<ExerciseType, LevelCacheEntry>? _levels;

  /// Nothing is drawn before the first read resolves: Home would flash the
  /// default selection first.
  bool _startupResolved = false;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
    _loadSetup();
  }

  @override
  void didUpdateWidget(covariant PlayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _loadStartupState();
  }

  /// Apart from [_loadStartupState]: a store that fails must not hide the
  /// levels read there. The default setup stays meanwhile.
  Future<void> _loadSetup() async {
    try {
      final setup = await widget.environment.gameSetupStore.load();
      if (setup != null && mounted) setState(() => _setup = setup);
    } on Exception catch (_) {
      // The default setup.
    }
    try {
      final chain = await widget.environment.chainSetupStore.load();
      if (chain != null && mounted) setState(() => _chainSetup = chain);
    } on Exception catch (_) {
      // The default chain setup.
    }
  }

  Future<void> _loadStartupState() async {
    // Auxiliary: a failure must never prevent playing with the defaults.
    final environment = widget.environment;
    try {
      final results = await Future.wait([
        environment.typeSelectionStore.load(),
        environment.repository.currentLevels(environment.playerId),
      ]);
      if (!mounted) return;
      final storedSelection = results[0] as Set<ExerciseType>?;
      setState(() {
        if (storedSelection != null) _selectedTypes = storedSelection;
        _levels = results[1] as Map<ExerciseType, LevelCacheEntry>;
        _startupResolved = true;
      });
    } on Exception catch (_) {
      if (mounted) setState(() => _startupResolved = true);
    }
  }

  void _toggle(ExerciseType type) {
    final updated = {..._selectedTypes};
    if (!updated.remove(type)) updated.add(type);
    setState(() => _selectedTypes = updated);
    // In the background: a failed write only costs the default next time.
    widget.environment.typeSelectionStore.save(updated).ignore();
  }

  /// [change] applies to the current setup, not to the one a widget was
  /// built with: two taps between frames both count.
  void _updateSetup(GameSetup Function(GameSetup) change) {
    final setup = change(_setup);
    setState(() => _setup = setup);
    widget.environment.gameSetupStore.save(setup).ignore();
  }

  Set<ExerciseType> _selectionOf(ExerciseFamily family) => {
    for (final type in family.types)
      if (_selectedTypes.contains(type)) type,
  };

  void _openSetup(ExerciseFamily family) => setState(() {
    _setupFamily = family;
    _startError = null;
  });

  void _closeSetup() => setState(() {
    _setupFamily = null;
    _chainSetupOpen = false;
  });

  void _updateChainSetup(ChainSetup Function(ChainSetup) change) {
    final setup = change(_chainSetup);
    setState(() => _chainSetup = setup);
    // In the background: a failed write only costs the default next time.
    widget.environment.chainSetupStore.save(setup).ignore();
  }

  Future<void> _startChain() async {
    await playChain(
      context,
      widget.environment,
      secondsPerScreen: _chainSetup.secondsPerScreen,
      operations: _chainSetup.operations,
    );
    if (mounted) setState(() => _chainSetupOpen = false);
  }

  Future<void> _start() {
    final types = _selectionOf(_setupFamily!);
    final setup = _setup;
    return _run(
      () => buildSessionController(widget.environment, types, setup: setup),
      setup: setup,
    );
  }

  Future<void> _run(
    Future<SessionController> Function() build, {
    GameSetup? setup,
  }) async {
    setState(() {
      _isStarting = true;
      _startError = null;
    });
    final SessionController controller;
    try {
      controller = await build();
    } catch (_) {
      if (!mounted) return;
      // Start, active again, is the retry.
      setState(() {
        _isStarting = false;
        _startError = 'Could not start';
      });
      return;
    }
    if (!mounted) return;
    // Back on Home after the game: its levels are what moved.
    setState(() {
      _isStarting = false;
      _setupFamily = null;
    });
    await playSessionFlow(
      context,
      widget.environment,
      controller,
      setup: setup,
    );
    if (mounted) await _loadStartupState();
  }

  @override
  Widget build(BuildContext context) {
    if (!_startupResolved) return const SizedBox.expand();
    if (_chainSetupOpen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSetup();
        },
        child: _ChainSetupView(
          seconds: _chainSetup.secondsPerScreen,
          operations: _chainSetup.operations,
          onSeconds: (s) =>
              _updateChainSetup((c) => c.copyWith(secondsPerScreen: s)),
          onOperations: (n) =>
              _updateChainSetup((c) => c.copyWith(operations: n)),
          onBack: _closeSetup,
          onStart: _startChain,
        ),
      );
    }
    final family = _setupFamily;
    if (family != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSetup();
        },
        child: _SetupView(
          types: _selectionOf(family),
          setup: _setup,
          onChanged: _updateSetup,
          onBack: _closeSetup,
          onStart: _isStarting ? null : _start,
          isStarting: _isStarting,
          startError: _startError,
        ),
      );
    }
    final levels = _levels ?? const {};
    return _HomeView(
      mainLevel: mainLevel(levels).round(),
      levelOf: (type) => (levels[type]?.level ?? Level.zero).whole,
      selectionOf: _selectionOf,
      onToggle: _toggle,
      onPlay: _openSetup,
      onGetTheCount: () => playCount(context, widget.environment),
      onChainOperations: () => setState(() => _chainSetupOpen = true),
    );
  }
}

/// Mockup 1. Labels only.
class _HomeView extends StatelessWidget {
  const _HomeView({
    required this.mainLevel,
    required this.levelOf,
    required this.selectionOf,
    required this.onToggle,
    required this.onPlay,
    required this.onGetTheCount,
    required this.onChainOperations,
  });

  final int mainLevel;
  final int Function(ExerciseType type) levelOf;
  final Set<ExerciseType> Function(ExerciseFamily family) selectionOf;
  final ValueChanged<ExerciseType> onToggle;
  final ValueChanged<ExerciseFamily> onPlay;
  final VoidCallback? onGetTheCount;
  final VoidCallback? onChainOperations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return SingleChildScrollView(
      padding: metrics.rootPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Play', style: theme.textTheme.titleMedium)),
              LevelBadge(level: mainLevel),
            ],
          ),
          for (final family in ExerciseFamily.values) ...[
            _SectionLabel(switch (family) {
              ExerciseFamily.basics => 'Basics',
              ExerciseFamily.advanced => 'Advanced',
            }),
            Row(
              children: [
                for (final (i, type) in family.types.indexed) ...[
                  if (i > 0) SizedBox(width: metrics.keyGap * 1.5),
                  Expanded(
                    child: OperationButton(
                      type: type,
                      level: levelOf(type),
                      selected: selectionOf(family).contains(type),
                      onTap: () => onToggle(type),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            AppButton.primary(
              key: playButtonKey(family),
              label: 'Play',
              semanticLabel: switch (family) {
                ExerciseFamily.basics => 'Play Basics',
                ExerciseFamily.advanced => 'Play Advanced',
              },
              compact: true,
              // Dimmed and inert until the row has a selection.
              onPressed: selectionOf(family).isEmpty
                  ? null
                  : () => onPlay(family),
            ),
          ],
          const _SectionLabel('Challenges'),
          AppCard(label: 'Get the count', onTap: onGetTheCount),
          const SizedBox(height: 8),
          AppCard(label: 'Chain operations', onTap: onChainOperations),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Mockup 2: back, the selected operators as the title, Questions, Mode,
/// the difficulty in Training only, Start at the bottom.
class _SetupView extends StatelessWidget {
  const _SetupView({
    required this.types,
    required this.setup,
    required this.onChanged,
    required this.onBack,
    required this.onStart,
    required this.isStarting,
    required this.startError,
  });

  final Set<ExerciseType> types;
  final GameSetup setup;
  final ValueChanged<GameSetup Function(GameSetup)> onChanged;
  final VoidCallback onBack;
  final VoidCallback? onStart;
  final bool isStarting;
  final String? startError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    final title = [
      for (final type in types.toList()..sort((a, b) => a.index - b.index))
        operatorSymbol(type),
    ].join(' ');
    // Scrolls only when large text needs it; Start otherwise sits at the
    // bottom.
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    // Balances the back button: the title stays centred.
                    const SizedBox(width: 48),
                  ],
                ),
                const _SectionLabel('Questions'),
                SegmentedChoice<int>(
                  values: questionsPerOperationChoices,
                  selected: setup.questionsPerOperation,
                  label: (n) => '$n',
                  onChanged: (n) =>
                      onChanged((s) => s.copyWith(questionsPerOperation: n)),
                ),
                const _SectionLabel('Mode'),
                SegmentedChoice<GameMode>(
                  values: GameMode.values,
                  selected: setup.mode,
                  label: (mode) => switch (mode) {
                    GameMode.training => 'Training',
                    GameMode.levelling => 'Levelling',
                  },
                  onChanged: (mode) => onChanged((s) => s.copyWith(mode: mode)),
                ),
                if (setup.mode == GameMode.training) ...[
                  const SizedBox(height: 8),
                  SegmentedChoice<TrainingDifficulty>(
                    values: TrainingDifficulty.values,
                    selected: setup.difficulty,
                    label: (difficulty) => switch (difficulty) {
                      TrainingDifficulty.easy => 'Easy',
                      TrainingDifficulty.medium => 'Medium',
                      TrainingDifficulty.hard => 'Hard',
                    },
                    onChanged: (difficulty) =>
                        onChanged((s) => s.copyWith(difficulty: difficulty)),
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 24),
                if (startError case final error?) ...[
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                AppButton.primary(
                  label: 'Start',
                  onPressed: onStart,
                  busy: isStarting,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The chain's setup page (mockup 2's layout): seconds per screen and the
/// number of operations, then Start.
class _ChainSetupView extends StatelessWidget {
  const _ChainSetupView({
    required this.seconds,
    required this.operations,
    required this.onSeconds,
    required this.onOperations,
    required this.onBack,
    required this.onStart,
  });

  final int seconds;
  final int operations;
  final ValueChanged<int> onSeconds;
  final ValueChanged<int> onOperations;
  final VoidCallback onBack;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: metrics.rootPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(
                        'Chain operations',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const _SectionLabel('Seconds'),
                SegmentedChoice<int>(
                  values: chainSecondsChoices,
                  selected: seconds,
                  label: (s) => '$s',
                  onChanged: onSeconds,
                ),
                const _SectionLabel('Operations'),
                SegmentedChoice<int>(
                  values: chainOperationChoices,
                  selected: operations,
                  label: (n) => '$n',
                  onChanged: onOperations,
                ),
                const Spacer(),
                const SizedBox(height: 24),
                AppButton.primary(label: 'Start', onPressed: onStart),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
