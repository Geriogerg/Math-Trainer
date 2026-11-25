import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../../core/state/online_controller.dart';
import '../theme/app_theme.dart';
import 'leaderboard_screen.dart';
import 'online_screen.dart';
import 'play_tab.dart';
import 'profile_screen.dart';

/// The app's permanent shell: a bottom tab bar with four entries
/// (`doc/design.md` — no side drawer, `doc/decisions.md`). `IndexedStack`
/// rather than a switch on the active tab: each tab keeps its state
/// (current type selection, etc.) once visited, rather than being rebuilt
/// on every return.
///
/// Tabs are only built on their first visit (`_visited`): a naive
/// `IndexedStack` builds its four children at launch, so `ProfileScreen`
/// would read the level cache immediately even if the player never leaves
/// the Play tab — a useless disk read at every start, and a source of
/// failure (e.g. a read that throws) unrelated to the tab actually shown.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;

  /// Passed down to the day/night switch on Profile — `null` by default so
  /// as not to break tests that build `AppShell` without caring about the
  /// theme.
  final VoidCallback? onToggleTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final _visited = {0};

  /// The Online tab's state, held here for the tab's badge (plan v3.7:
  /// in-app badges): loaded at start — which also sends the duel runs
  /// still on the device — and again whenever the tab is shown.
  OnlineController? _online;

  @override
  void initState() {
    super.initState();
    _online = _buildOnline(widget.environment);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.environment.playerId != widget.environment.playerId) {
      _online?.dispose();
      _online = _buildOnline(widget.environment);
    }
  }

  static OnlineController? _buildOnline(AppEnvironment environment) {
    final repository = environment.onlineRepository;
    if (repository == null) return null;
    return OnlineController(
      repository: repository,
      client: environment.duelClient,
      queue: environment.duelQueue,
      levels: () async => {
        for (final MapEntry(:key, :value)
            in (await environment.repository.currentLevels(
              environment.playerId,
            )).entries)
          key: value.level,
      },
    )..load().ignore();
  }

  /// Tab change fade (`AppMotion.tabChange`) — animates an `Opacity` over
  /// the `IndexedStack`, which stays intact: replacing it with a widget
  /// rebuilt at each switch would lose each tab's state (the current type
  /// selection on Play, among others). Duration set just before
  /// `.forward()` (unavailable before the first frame), same pattern as
  /// `_feedbackController` in `session_screen.dart`.
  late final AnimationController _tabTransitionController = AnimationController(
    vsync: this,
    value: 1,
  );

  void _selectTab(int index) {
    if (index == 1 && _index != 1) _online?.load().ignore();
    setState(() {
      _index = index;
      _visited.add(index);
    });
    final motion = Theme.of(context).extension<AppMotion>()!.tabChange;
    _tabTransitionController
      // Reduced motion: the tab appears at once.
      ..duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : motion.duration
      ..value = 0
      ..animateTo(1, curve: motion.curve);
  }

  @override
  void dispose() {
    _online?.dispose();
    _tabTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PlayTab(environment: widget.environment, isActive: _index == 0),
      OnlineScreen(environment: widget.environment, controller: _online),
      ProfileScreen(
        environment: widget.environment,
        isActive: _index == 2,
        onToggleTheme: widget.onToggleTheme,
      ),
      LeaderboardScreen(environment: widget.environment, isActive: _index == 3),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _tabTransitionController,
          builder: (context, child) =>
              Opacity(opacity: _tabTransitionController.value, child: child),
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _visited.contains(i) ? tabs[i] : const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: _online ?? const AlwaysStoppedAnimation(0),
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.sports_esports_outlined),
              label: 'Play',
            ),
            NavigationDestination(
              // A challenge or a friend request waiting: a dot, and the
              // tab's name says so to screen readers (rule 14).
              icon: Badge(
                isLabelVisible: _online?.needsAttention ?? false,
                child: const Icon(Icons.wifi_outlined),
              ),
              label: 'Online',
              tooltip: (_online?.needsAttention ?? false)
                  ? 'Online, something waits for you'
                  : null,
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
            const NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              // The mockups' word (doc/decisions.md, Redesign phase).
              label: 'Ranks',
            ),
          ],
        ),
      ),
    );
  }
}
