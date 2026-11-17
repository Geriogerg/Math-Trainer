import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../theme/app_theme.dart';
import 'coming_soon_screen.dart';
import 'play_tab.dart';
import 'profile_screen.dart';

/// Coquille permanente de l'app : barre d'onglets basse à quatre entrées
/// (`doc/design.md` — pas de tiroir latéral, `doc/decisions.md`).
/// `IndexedStack` plutôt qu'un switch sur l'onglet actif : chaque onglet
/// garde son état (sélection de types en cours, etc.) une fois visité,
/// plutôt que d'être reconstruit à chaque retour.
///
/// Les onglets ne sont construits qu'à la première visite (`_visited`) : un
/// `IndexedStack` naïf construit ses quatre enfants dès le lancement, donc
/// `ProfileScreen` lirait le cache de niveaux immédiatement même si le
/// joueur ne quitte jamais l'onglet Jouer — un aller-disque inutile à
/// chaque démarrage, et une source d'échec (ex. lecture qui lève) sans
/// rapport avec l'onglet réellement affiché.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;

  /// Relayé jusqu'au bouton nuit/jour de `PlayTab` — `null` par défaut pour
  /// ne pas casser les tests qui construisent `AppShell` sans s'intéresser
  /// au thème.
  final VoidCallback? onToggleTheme;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  final _visited = {0};

  /// Fondu de changement d'onglet (`AppMotion.tabChange`) — anime une
  /// `Opacity` par-dessus l'`IndexedStack`, qui lui reste intact : le
  /// remplacer par un widget reconstruit à chaque bascule perdrait l'état de
  /// chaque onglet (sélection de types en cours sur Jouer, entre autres).
  /// Durée posée juste avant `.forward()` (indisponible avant le premier
  /// frame), même schéma que `_feedbackController` de `session_screen.dart`.
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
      ),
      const ComingSoonScreen(label: 'En ligne'),
      ProfileScreen(environment: widget.environment, isActive: _index == 2),
      const ComingSoonScreen(label: 'Classement'),
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
            label: 'Jouer',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            label: 'En ligne',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            label: 'Classement',
          ),
        ],
      ),
    );
  }
}
