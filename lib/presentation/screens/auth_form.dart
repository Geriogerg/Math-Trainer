import 'package:flutter/material.dart';

import '../../core/domain/account/account_repository.dart';
import '../theme/app_theme.dart';

enum _AuthMode { signIn, signUp }

/// The raw server message (written for a developer) only appears for an
/// unlisted failure — the only clue available in that case.
String _describeError(Object error) {
  if (error is! AccountException) return 'Unexpected error: $error';
  return switch (error.failure) {
    AccountFailure.invalidCredentials => 'Incorrect email or password.',
    AccountFailure.emailNotConfirmed =>
      'Email not confirmed yet — open the link in the email, then try again.',
    AccountFailure.emailAlreadyUsed =>
      'An account already exists with this email. Sign in instead.',
    AccountFailure.weakPassword =>
      // No length quoted: the minimum is set per Supabase project.
      'Password too weak — choose a longer one.',
    AccountFailure.invalidInput => 'Invalid email address.',
    AccountFailure.rateLimited =>
      'Too many attempts. Wait a few minutes before trying again.',
    AccountFailure.network =>
      'Server unreachable. Check your connection, then try again.',
    AccountFailure.unknown => 'Unexpected error: ${error.detail ?? '-'}',
  };
}

/// Sign-in/sign-up form — the app's entry gate (`AuthGate`, mandatory
/// sign-in, `doc/online.md`). Extracted from the former `OnlineTab` (step
/// 6, slice 1): signing in is no longer a tab but a gate at app level.
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
    // Mobile keyboard autocompletion often adds a space after the email,
    // which the server would reject as an invalid address.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _error = 'Enter your email and password.';
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
          // Email confirmation required: not signed in yet, authState stays
          // `null` (`account_repository.dart`) — switch to the sign-in form
          // rather than leaving the sign-up form shown as if nothing had
          // happened.
          setState(() {
            _isSubmitting = false;
            _mode = _AuthMode.signIn;
            _info =
                'Account created — check your inbox to confirm, then sign in.';
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
    // Success with an active session: `AuthGate.authState` will emit the
    // signed-in account and rebuild above this widget — nothing to do here.
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
                  isSignUp ? 'Create an account' : 'Sign in',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                // `AutofillGroup` + `autofillHints`: the browser/phone password
                // manager suggests and saves the credentials. Enter in the
                // password field submits the form.
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
                          labelText: 'Password',
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
                      : Text(isSignUp ? 'Create account' : 'Sign in'),
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
                        ? 'Already have an account? Sign in'
                        : 'No account? Sign up',
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
