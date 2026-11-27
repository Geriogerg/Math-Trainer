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
import 'package:math_trainer/presentation/strings/exercise_type_labels.dart';
import '../kit/kit.dart';
import '../strings/strings.dart';
import '../theme/app_theme.dart';
import '../../core/state/levels_refresh.dart';
import 'chain_screen.dart';
import 'count_screen.dart';
import 'session_flow_screen.dart';
import 'sign_in_screen.dart';
import 'tips_view.dart';
import 'package:math_trainer/presentation/strings/tips.dart';

part 'home_view.dart';
part 'setup_views.dart';

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

  /// A guest: with no level anywhere, Home suggests signing in (Phase 6b
  /// commit 5, review M14: after a storage eviction the app silently made
  /// a new guest, and nothing said the old progress was one sign-in away).
  bool _guest = false;

  /// Read at [initState]: told when the server's levels replaced the local
  /// ones at sign-in.
  LevelsRefresh? _levelsRefresh;

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
    _loadGuest();
    _levelsRefresh = widget.environment.levelsRefresh
      ?..addListener(_loadStartupState);
  }

  @override
  void dispose() {
    _levelsRefresh?.removeListener(_loadStartupState);
    super.dispose();
  }

  Future<void> _loadGuest() async {
    try {
      final account =
          await widget.environment.accountRepository.authState.first;
      if (mounted) setState(() => _guest = account?.isAnonymous ?? false);
    } on Exception catch (_) {
      // No hint.
    }
  }

  /// Sign in to an existing account; `AuthGate` swaps the whole shell on
  /// success.
  void _signIn() {
    final environment = widget.environment;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          accountRepository: environment.accountRepository,
          profileRepository: environment.profileRepository,
          isGuest: true,
        ),
      ),
    );
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
        title: strings.home.chainOperations,
        lines: strings.home.chainRules,
        cancellable: false,
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
        _startError = strings.home.couldNotStart;
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
      // The whole part, as everywhere (review m3: rounded here, floored on
      // Ranks).
      mainLevel: mainLevel(levels).floor(),
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
      onSignIn:
          _guest &&
              _startupResolved &&
              levels.values.every((entry) => entry.level == Level.zero)
          ? _signIn
          : null,
    );
  }
}
