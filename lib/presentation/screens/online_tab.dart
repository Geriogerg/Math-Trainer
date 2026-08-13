import 'package:flutter/material.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import '../../core/domain/account/account_repository.dart';
import '../theme/app_theme.dart';

/// Onglet « En ligne » de `AppShell`. Étape 6, tranche 1 (`doc/online.md`) :
/// création de compte et connexion seulement, pas de classement ni de duels
/// ici.
class OnlineTab extends StatelessWidget {
  const OnlineTab({super.key, required this.environment});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Account?>(
      stream: environment.accountRepository.authState,
      builder: (context, snapshot) {
        final account = snapshot.data;
        return account == null
            ? _AuthForm(accountRepository: environment.accountRepository)
            : _SignedInView(
                account: account,
                accountRepository: environment.accountRepository,
              );
      },
    );
  }
}

enum _AuthMode { signIn, signUp }

class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.accountRepository});

  final AccountRepository accountRepository;

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  _AuthMode _mode = _AuthMode.signIn;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
      _info = null;
    });
    final email = _emailController.text;
    final password = _passwordController.text;
    try {
      if (_mode == _AuthMode.signUp) {
        final account = await widget.accountRepository.signUp(
          email: email,
          password: password,
        );
        if (!mounted) return;
        if (account == null) {
          // Confirmation par email requise : pas encore connecté, authState
          // reste `null` (`account_repository.dart`) — bascule vers le
          // formulaire de connexion plutôt que de laisser l'inscription
          // affichée comme si de rien n'était.
          setState(() {
            _isSubmitting = false;
            _mode = _AuthMode.signIn;
            _info =
                'Compte créé — vérifie ta boîte mail pour confirmer, puis connecte-toi.';
          });
          return;
        }
      } else {
        await widget.accountRepository.signIn(email: email, password: password);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _mode == _AuthMode.signUp
            ? 'Impossible de créer le compte.'
            : 'Impossible de se connecter.';
      });
      return;
    }
    // Succès avec session active : `OnlineTab.authState` émettra le compte
    // connecté et reconstruira au-dessus de ce widget — rien à faire ici.
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSignUp = _mode == _AuthMode.signUp;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: theme.extension<AppMetrics>()!.rootPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSignUp ? 'Créer un compte' : 'Se connecter',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mot de passe'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isSignUp ? 'Créer le compte' : 'Se connecter'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                          _mode = isSignUp
                              ? _AuthMode.signIn
                              : _AuthMode.signUp;
                          _error = null;
                          _info = null;
                        }),
                  child: Text(
                    isSignUp
                        ? 'Déjà un compte ? Se connecter'
                        : 'Pas de compte ? S\'inscrire',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ] else if (_info != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _info!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedInView extends StatefulWidget {
  const _SignedInView({required this.account, required this.accountRepository});

  final Account account;
  final AccountRepository accountRepository;

  @override
  State<_SignedInView> createState() => _SignedInViewState();
}

class _SignedInViewState extends State<_SignedInView> {
  bool _isSigningOut = false;
  String? _error;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
      _error = null;
    });
    try {
      await widget.accountRepository.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = 'Impossible de se déconnecter.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: theme.extension<AppMetrics>()!.rootPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connecté', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(widget.account.email, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSigningOut ? null : _signOut,
              child: _isSigningOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Se déconnecter'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
