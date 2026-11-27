import 'package:material_ui/material_ui.dart';

import 'package:math_core/challenges/chain.dart';
import 'package:math_core/challenges/tables.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/main_level.dart';
import 'package:math_core/models/answer_result.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/game_setup.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/weak_spots/item.dart';
import '../../composition_root.dart';
import '../../core/state/hints.dart';
import '../../core/state/session_controller.dart';
import '../exercise_type_labels.dart';
import '../kit/kit.dart';
import '../theme/app_theme.dart';
import 'chain_screen.dart';
import 'count_screen.dart';
import 'session_flow_screen.dart';
import 'tips_view.dart';
import '../tips/tips.dart';

/// Addition and subtraction ticked for a player who never chose: inverse
/// operations, the lightest start (step 4.1, `doc/decisions.md`).
const _defaultSelectedTypes = {ExerciseType.addition, ExerciseType.subtraction};

/// Stable handles for tests on the Home rows' Play buttons.
ValueKey<String> playButtonKey(ExerciseFamily family) =>
    ValueKey('play-${family.name}');

/// The Weak spots card on Home (Phase 4).
const weakSpotsCardKey = ValueKey<String>('weak-spots');

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

  /// Tables mode's setup page is open (`doc/levels.md` section 7), and its
  /// choices, remembered (`TablesStore`).
  bool _tablesSetupOpen = false;
  TablesSetup _tablesSetup = TablesSetup();

  /// The Tips page is open (`doc/levels.md` section 8).
  bool _tipsOpen = false;

  /// The first-run card is shown until the player dismisses it (Phase 6b
  /// commit 4, review M16); never without a hints store (tests).
  bool _firstRun = false;

  bool _isStarting = false;
  String? _startError;

  /// `null` until read, or if the read failed (levels then show as 0).
  Map<ExerciseType, LevelCacheEntry>? _levels;

  /// The Weak spots game Home offers (Phase 4); `null` until read or if
  /// the read failed (the card then shows no count and stays inert).
  List<Item>? _weakSpots;

  /// Nothing is drawn before the first read resolves: Home would flash the
  /// default selection first.
  bool _startupResolved = false;

  @override
  void initState() {
    super.initState();
    _loadStartupState();
    _loadSetup();
    _loadFirstRun();
  }

  Future<void> _loadFirstRun() async {
    final hints = widget.environment.hints;
    if (hints == null) return;
    try {
      final seen = await hints.seen(Hint.firstRun);
      if (!seen && mounted) setState(() => _firstRun = true);
    } on Exception catch (_) {
      // Not shown: a store that fails never blocks Home.
    }
  }

  void _dismissFirstRun() {
    setState(() => _firstRun = false);
    widget.environment.hints?.markSeen(Hint.firstRun).ignore();
  }

  /// Chain operations' setup, its rules first on the first open (review
  /// m17: "Get the count and Chain operations open with no rules").
  Future<void> _openChainSetup() async {
    final hints = widget.environment.hints;
    if (hints != null && !await hints.seen(Hint.chainRules)) {
      if (!mounted) return;
      await showRules(
        context,
        title: 'Chain operations',
        lines: const [
          'A number, then one operation a screen. Keep the result in your '
              'head; type it at the end.',
          'Practice: it never moves your levels.',
        ],
        confirm: null,
      );
      await hints.markSeen(Hint.chainRules);
    }
    if (mounted) setState(() => _chainSetupOpen = true);
  }

  @override
  void didUpdateWidget(covariant PlayTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _loadStartupState();
  }

  /// Apart from [_loadStartupState]: a store that fails must not hide the
  /// levels read there. Each setup on its own, so one store that fails or
  /// never answers leaves the others' choices; the defaults stay meanwhile.
  void _loadSetup() {
    _loadOne(widget.environment.gameSetupStore.load, (s) => _setup = s);
    _loadOne(widget.environment.chainSetupStore.load, (s) => _chainSetup = s);
    _loadOne(widget.environment.tablesStore.loadSetup, (s) => _tablesSetup = s);
  }

  Future<void> _loadOne<T extends Object>(
    Future<T?> Function() load,
    void Function(T stored) apply,
  ) async {
    try {
      final stored = await load();
      if (stored != null && mounted) setState(() => apply(stored));
    } on Exception catch (_) {
      // The default.
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
    // Apart: a history that cannot be read must not hide the levels.
    try {
      final items = await weakSpotsGameItems(environment);
      if (mounted) setState(() => _weakSpots = items);
    } on Exception catch (_) {
      if (mounted) setState(() => _weakSpots = null);
    }
  }

  /// A Drill of [tip] (Phase 4); Play again deals another of the same tip.
  Future<void> _startDrill(Tip tip) async {
    final environment = widget.environment;
    Future<SessionController> build() => buildDrillController(
      environment,
      type: tip.type,
      families: tip.families,
      band: tip.band,
    );
    final SessionController controller;
    try {
      controller = await build();
    } on Exception catch (_) {
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    await playSessionFlow(context, environment, controller, playAgain: build);
    if (mounted) await _loadStartupState();
  }

  /// A Weak spots game of the items due now; Play again deals the next
  /// ones (the schedule has moved).
  Future<void> _startWeakSpots() async {
    final environment = widget.environment;
    final items = _weakSpots;
    if (items == null || items.isEmpty) return;
    final controller = await buildWeakSpotsController(environment, items);
    if (!mounted) {
      controller.dispose();
      return;
    }
    await playSessionFlow(
      context,
      environment,
      controller,
      playAgain: () async {
        final next = await weakSpotsGameItems(environment);
        if (next.isEmpty) throw StateError('Nothing due.');
        return buildWeakSpotsController(environment, next);
      },
    );
    if (mounted) await _loadStartupState();
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
    _tablesSetupOpen = false;
    _tipsOpen = false;
  });

  void _updateTablesSetup(TablesSetup Function(TablesSetup) change) {
    final setup = change(_tablesSetup);
    setState(() => _tablesSetup = setup);
    // In the background: a failed write only costs the default next time.
    widget.environment.tablesStore.saveSetup(setup).ignore();
  }

  /// A round of Tables mode on the game screen; Play again deals a new one
  /// from the same setup. Each finished round goes into the device's stats.
  Future<void> _startTables() async {
    final environment = widget.environment;
    final setup = _tablesSetup;
    setState(() => _tablesSetupOpen = false);
    await playSessionFlow(
      context,
      environment,
      buildTablesController(environment, setup),
      playAgain: () => buildTablesController(environment, setup),
      // Practice of facts: no Method (`doc/levels.md` section 9).
      showMethods: false,
      onFinished: (controller) => _recordTables(controller.state.outcomes),
    );
  }

  Future<void> _recordTables(List<AnswerResult> outcomes) async {
    final store = widget.environment.tablesStore;
    try {
      await store.saveStats((await store.loadStats()).record(outcomes));
    } on Exception catch (_) {
      // Stats are a convenience: a failed write never interrupts play.
    }
  }

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
    if (_tipsOpen) {
      final levels = _levels ?? const {};
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSetup();
        },
        child: TipsView(
          levelOf: (type) => levels[type]?.level ?? Level.zero,
          onBack: _closeSetup,
          onDrill: _startDrill,
        ),
      );
    }
    if (_tablesSetupOpen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _closeSetup();
        },
        child: _TablesSetupView(
          setup: _tablesSetup,
          onChanged: _updateTablesSetup,
          onBack: _closeSetup,
          onStart: _startTables,
        ),
      );
    }
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
      onChainOperations: _openChainSetup,
      onTables: () => setState(() => _tablesSetupOpen = true),
      onTips: () => setState(() => _tipsOpen = true),
      weakSpotsDue: _weakSpots?.length,
      onWeakSpots: _startWeakSpots,
      firstRun: _firstRun,
      onDismissFirstRun: _dismissFirstRun,
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
    required this.onTables,
    required this.onTips,
    this.weakSpotsDue,
    this.onWeakSpots,
    this.firstRun = false,
    this.onDismissFirstRun,
  });

  final int mainLevel;

  /// The first-run card, until dismissed (Phase 6b commit 4).
  final bool firstRun;
  final VoidCallback? onDismissFirstRun;
  final int Function(ExerciseType type) levelOf;
  final Set<ExerciseType> Function(ExerciseFamily family) selectionOf;
  final ValueChanged<ExerciseType> onToggle;
  final ValueChanged<ExerciseFamily> onPlay;
  final VoidCallback? onGetTheCount;
  final VoidCallback? onChainOperations;
  final VoidCallback? onTables;
  final VoidCallback? onTips;

  /// Weak spots the player can practise now (Phase 4); `null`: unknown.
  final int? weakSpotsDue;
  final VoidCallback? onWeakSpots;

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
          const Caption(
            'Your level: the mean of + − × ÷.',
            textAlign: TextAlign.end,
          ),
          if (firstRun) ...[
            const SizedBox(height: 12),
            _FirstRunCard(onDismiss: onDismissFirstRun),
          ],
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
            Caption(switch (family) {
              ExerciseFamily.basics =>
                'Tap the operations to play. Each has its own level, 0–100.',
              ExerciseFamily.advanced =>
                'Squares, roots, percentages, integrals: levels of their own.',
            }),
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
          // Phase 4: the player's own weak spots, practice only.
          const _SectionLabel('Practice'),
          AppCard(
            key: weakSpotsCardKey,
            label: 'Weak spots',
            caption: 'What you missed, asked again.',
            detail: switch (weakSpotsDue) {
              null => null,
              0 => 'None due',
              final n => '$n due',
            },
            onTap: (weakSpotsDue ?? 0) > 0 ? onWeakSpots : null,
          ),
          const _SectionLabel('Challenges'),
          AppCard(
            label: 'Get the count',
            caption: 'Reach a target with the numbers given.',
            onTap: onGetTheCount,
          ),
          const SizedBox(height: 8),
          AppCard(
            label: 'Chain operations',
            caption: 'A running total, kept in your head.',
            onTap: onChainOperations,
          ),
          const SizedBox(height: 8),
          // Its own card, under Challenges (`doc/levels.md`, section 7).
          AppCard(
            label: 'Tables',
            caption: 'Times tables, at your pace. Never ranked.',
            onTap: onTables,
          ),
          const SizedBox(height: 8),
          // Reached from its own card (`doc/levels.md`, section 8).
          AppCard(
            label: 'Tips',
            caption: 'Shortcuts for every operation and level.',
            onTap: onTips,
          ),
        ],
      ),
    );
  }
}

/// What a newcomer needs before the first game (Phase 6b commit 4, review
/// M16): how a level moves, in three lines; gone once dismissed.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = theme.extension<AppMetrics>()!;
    return Container(
      key: firstRunCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(metrics.radius * 0.75),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How levels work', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            'Each operation has a level, 0 to 100. A Levelling game moves '
            'it: right answers raise it, fast ones most; mistakes, timeouts '
            'and quitting lower it.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Training games and Practice never move levels.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(label: 'Got it', onPressed: onDismiss),
          ),
        ],
      ),
    );
  }
}

/// The first-run card (tests find it by this key).
const firstRunCardKey = ValueKey('first-run-card');

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
                Caption(
                  types.length == 1
                      ? '${setup.questionsPerOperation} questions.'
                      : '${setup.questionsPerOperation} per operation: '
                            '${setup.questionsPerOperation * types.length} '
                            'questions in all.',
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
                Caption(switch (setup.mode) {
                  GameMode.levelling =>
                    'Moves your levels. Quitting counts the questions left '
                        'as missed.',
                  GameMode.training =>
                    'A fixed difficulty. Your levels never move.',
                }),
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
                  const Caption('Easy: level 10 · Medium: 40 · Hard: 70.'),
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

/// Tables mode's setup page (`doc/levels.md`, section 7): which tables (a
/// range within 1–50), multipliers 1–10 or 1–20, how many questions, then
/// Start. Labels only.
class _TablesSetupView extends StatelessWidget {
  const _TablesSetupView({
    required this.setup,
    required this.onChanged,
    required this.onBack,
    required this.onStart,
  });

  final TablesSetup setup;
  final void Function(TablesSetup Function(TablesSetup)) onChanged;
  final VoidCallback onBack;
  final VoidCallback onStart;

  /// The first table moves the last along when it passes it, and back.
  static TablesSetup _first(TablesSetup s, int first) => s.copyWith(
    firstTable: first,
    lastTable: s.lastTable < first ? first : s.lastTable,
  );

  static TablesSetup _last(TablesSetup s, int last) => s.copyWith(
    lastTable: last,
    firstTable: s.firstTable > last ? last : s.firstTable,
  );

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
                        'Tables',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
                const _SectionLabel('From'),
                _TableStepper(
                  key: const ValueKey('tables-from'),
                  value: setup.firstTable,
                  label: 'From',
                  onChanged: (v) => onChanged((s) => _first(s, v)),
                ),
                const _SectionLabel('To'),
                _TableStepper(
                  key: const ValueKey('tables-to'),
                  value: setup.lastTable,
                  label: 'To',
                  onChanged: (v) => onChanged((s) => _last(s, v)),
                ),
                const _SectionLabel('Multipliers'),
                SegmentedChoice<int>(
                  values: tablesMultiplierChoices,
                  selected: setup.maxMultiplier,
                  label: (m) => '1–$m',
                  onChanged: (m) =>
                      onChanged((s) => s.copyWith(maxMultiplier: m)),
                ),
                const _SectionLabel('Questions'),
                SegmentedChoice<int>(
                  values: tablesQuestionChoices,
                  selected: setup.questions,
                  label: (n) => '$n',
                  onChanged: (n) => onChanged((s) => s.copyWith(questions: n)),
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

/// A table number in [tablesMin, tablesMax]: − and + (48 dp each), the value
/// between them in the digit face. Screen readers hear "From 12".
class _TableStepper extends StatelessWidget {
  const _TableStepper({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          tooltip: '$label −1',
          onPressed: value > tablesMin ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 88,
          child: Text(
            '$value',
            semanticsLabel: '$label $value',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.digits,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '$label +1',
          onPressed: value < tablesMax ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}
