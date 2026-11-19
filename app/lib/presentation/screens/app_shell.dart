import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../theme/app_theme.dart';
import 'coming_soon_screen.dart';
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

  /// Passed down to the day/night button of `PlayTab` — `null` by default so
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
    setState(() {
      _index = index;
      _visited.add(index);
    });
    final motion = Theme.of(context).extension<AppMotion>()!.tabChange;
    _tabTransitionController
      ..duration = motion.duration
      ..value = 0
      ..animateTo(1, curve: motion.curve);
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      PlayTab(
        environment: widget.environment,
        onToggleTheme: widget.onToggleTheme,
        isActive: _index == 0,
      ),
      const ComingSoonScreen(label: 'Online'),
      ProfileScreen(environment: widget.environment, isActive: _index == 2),
      const ComingSoonScreen(label: 'Leaderboard'),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            label: 'Online',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Leaderboard',
          ),
        ],
      ),
    );
  }
}
