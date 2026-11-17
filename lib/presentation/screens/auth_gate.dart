import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import 'app_shell.dart';
import 'auth_form.dart';

/// Porte d'entrée de l'app — connexion obligatoire (`doc/online.md`, étape 6
/// tranche 2). La session Supabase est persistée localement : un joueur déjà
/// connecté retrouve son compte sans réseau au lancement suivant, seul un
/// premier lancement (jamais connecté sur cet appareil) ou une déconnexion
/// explicite affiche le formulaire.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Créé une seule fois : `authState` renvoie un nouveau `Stream` à chaque
  /// lecture, et `StreamBuilder` se réabonne dès que l'instance change — il
  /// repasse alors par `waiting`, ce qui démonte puis recrée `AppShell`
  /// (onglet courant et état perdus) à chaque reconstruction du parent, par
  /// exemple à chaque bascule nuit/jour.
  late final Stream<Account?> _authState =
      widget.environment.accountRepository.authState;

  @override
  Widget build(BuildContext context) {
    final environment = widget.environment;
    return StreamBuilder<Account?>(
      stream: _authState,
      builder: (context, snapshot) {
        // `waiting` : restauration de la session locale en cours (pas de
        // réseau nécessaire) — ne jamais afficher le formulaire à ce stade,
        // ça ferait clignoter la porte pour un joueur déjà connecté.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final account = snapshot.data;
        if (account == null) {
          return Scaffold(
            body: SafeArea(
              child: AuthForm(accountRepository: environment.accountRepository),
            ),
          );
        }
        return AppShell(
          environment: environment,
          onToggleTheme: widget.onToggleTheme,
        );
      },
    );
  }
}
