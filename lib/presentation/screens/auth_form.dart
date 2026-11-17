import 'package:flutter/material.dart';

import '../../core/domain/account/account_repository.dart';
import '../theme/app_theme.dart';

enum _AuthMode { signIn, signUp }

/// `Exception(message)` se formate en `Exception: message` — retire ce
/// préfixe technique. Le message lui-même vient tel quel de Supabase (pas
/// traduit — court terme, mais un mot de passe trop court ou un email déjà
/// utilisé reste plus utile en anglais qu'un message générique muet).
String _describeError(Object error) {
  final message = error.toString();
  const prefix = 'Exception: ';
  return message.startsWith(prefix)
      ? message.substring(prefix.length)
      : message;
}

/// Formulaire connexion/inscription — porte d'entrée de l'app (`AuthGate`,
/// connexion obligatoire, `doc/online.md`). Extrait de l'ancien `OnlineTab`
/// (étape 6, tranche 1) : la connexion n'est plus un onglet, mais une porte
/// au niveau de l'app.
class AuthForm extends StatefulWidget {
  const AuthForm({super.key, required this.accountRepository});

  final AccountRepository accountRepository;

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _describeError(e);
      });
      return;
    }
    // Succès avec session active : `AuthGate.authState` émettra le compte
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
