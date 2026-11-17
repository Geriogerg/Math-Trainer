import 'dart:async';

import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import 'app_shell.dart';
import 'auth_form.dart';

/// Porte d'entrée de l'app — connexion obligatoire (`doc/online.md`, étape 6
/// tranche 2). La session Supabase est persistée localement : un joueur déjà
/// connecté retrouve son compte sans réseau au lancement suivant, seul un
/// premier lancement (jamais connecté sur cet appareil) ou une déconnexion
/// explicite affiche le formulaire. Une fois connecté, tout ce qui suit
/// (niveaux, historique) est rattaché au compte, pas à l'appareil
/// (`environmentForAccount`).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<Account?> _authSubscription;

  /// `false` tant que la session locale n'est pas résolue (pas de réseau
  /// nécessaire) — ne jamais afficher le formulaire à ce stade, ça ferait
  /// clignoter la porte pour un joueur déjà connecté.
  bool _isResolved = false;
  Account? _account;

  /// Environnement du compte connecté (`environmentForAccount`), `null` tant
  /// que la reprise des parties de l'appareil n'a pas abouti — chargement
  /// affiché pendant ce temps, pour qu'aucun écran ne lise un historique
  /// encore incomplet.
  AppEnvironment? _playerEnvironment;

  @override
  void initState() {
    super.initState();
    // Abonnement unique, pas un `StreamBuilder` : `authState` renvoie un
    // nouveau `Stream` à chaque lecture, et un réabonnement repasserait par
    // l'état de chargement, ce qui démonterait puis recréerait `AppShell`
    // (onglet courant et état perdus) à chaque reconstruction du parent.
    _authSubscription = widget.environment.accountRepository.authState.listen(
      _onAccountChanged,
    );
  }

  Future<void> _onAccountChanged(Account? account) async {
    if (_isResolved && account?.id == _account?.id) return;
    setState(() {
      _isResolved = true;
      _account = account;
      _playerEnvironment = null;
    });
    if (account == null) return;
    final playerEnvironment = await environmentForAccount(
      widget.environment,
      account,
    );
    // Déconnexion ou changement de compte pendant la reprise : résultat
    // périmé, l'appel déclenché par le nouvel état s'en charge.
    if (!mounted || _account?.id != account.id) return;
    setState(() => _playerEnvironment = playerEnvironment);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final playerEnvironment = _playerEnvironment;
    if (_isResolved && account == null) {
      return Scaffold(
        body: SafeArea(
          child: AuthForm(
            accountRepository: widget.environment.accountRepository,
          ),
        ),
      );
    }
    if (account == null || playerEnvironment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AppShell(
      // Un autre compte repart d'un `AppShell` neuf : aucun état (niveau
      // affiché, onglet Profil) ne survit d'un joueur à l'autre.
      key: ValueKey(account.id),
      environment: playerEnvironment,
      onToggleTheme: widget.onToggleTheme,
    );
  }
}
