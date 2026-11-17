import 'package:flutter/material.dart';

import '../../core/domain/account/account_repository.dart';
import '../theme/app_theme.dart';

enum _AuthMode { signIn, signUp }

/// Le message brut du serveur (anglais, pensé pour un développeur) n'apparaît
/// que pour un échec non répertorié — seul indice disponible dans ce cas.
String _describeError(Object error) {
  if (error is! AccountException) return 'Erreur inattendue : $error';
  return switch (error.failure) {
    AccountFailure.invalidCredentials => 'Email ou mot de passe incorrect.',
    AccountFailure.emailNotConfirmed =>
      'Email pas encore confirmé — ouvre le lien reçu par mail, puis réessaie.',
    AccountFailure.emailAlreadyUsed =>
      'Un compte existe déjà avec cet email. Connecte-toi plutôt.',
    AccountFailure.weakPassword =>
      // Pas de longueur citée : le minimum se règle par projet Supabase.
      'Mot de passe trop faible — choisis-en un plus long.',
    AccountFailure.invalidInput => 'Adresse email invalide.',
    AccountFailure.rateLimited =>
      'Trop de tentatives. Patiente quelques minutes avant de réessayer.',
    AccountFailure.network =>
      'Serveur injoignable. Vérifie ta connexion, puis réessaie.',
    AccountFailure.unknown => 'Erreur inattendue : ${error.detail ?? '-'}',
  };
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
    // L'autocomplétion des claviers mobiles ajoute souvent une espace après
    // l'email, que le serveur refuserait comme adresse invalide.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Renseigne l\'email et le mot de passe.';
        _info = null;
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
      _info = null;
    });
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
                // `AutofillGroup` + `autofillHints` : le gestionnaire de mots de
                // passe du navigateur/téléphone propose et enregistre les
                // identifiants. Entrée dans le mot de passe valide le formulaire.
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: [
                          isSignUp
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onSubmitted: (_) {
                          if (!_isSubmitting) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe',
                        ),
                      ),
                    ],
                  ),
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
