import 'package:material_ui/material_ui.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';
import '../../core/state/account_form_controller.dart';
import '../account_messages.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';

/// "Save your progress" (plan, section 6.3): a guest links an email, a
/// password and a player name. Same account id afterwards, so levels and
/// history stay as they are. Pops with the [SaveProgressOutcome] on
/// success; offers to sign in instead when the email already has an
/// account.
class SaveProgressScreen extends StatefulWidget {
  const SaveProgressScreen({
    super.key,
    required this.accountRepository,
    required this.profileRepository,
    this.initialDisplayName = '',
    this.guestHasProgress = false,
  });

  final AccountRepository accountRepository;
  final ProfileRepository profileRepository;

  /// Pre-filled when the guest already chose a name.
  final String initialDisplayName;

  /// For the warning of [SignInScreen] if the player goes there instead.
  final bool guestHasProgress;

  @override
  State<SaveProgressScreen> createState() => _SaveProgressScreenState();
}

class _SaveProgressScreenState extends State<SaveProgressScreen> {
  late final AccountFormController _controller = AccountFormController(
    accounts: widget.accountRepository,
    profiles: widget.profileRepository,
  );
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _name = TextEditingController(text: widget.initialDisplayName);

  @override
  void dispose() {
    _controller.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final outcome = await _controller.saveProgress(
      email: _email.text,
      password: _password.text,
      displayName: _name.text,
    );
    if (!mounted || outcome == SaveProgressOutcome.failed) return;
    Navigator.of(context).pop(outcome);
  }

  void _signInInstead() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          accountRepository: widget.accountRepository,
          profileRepository: widget.profileRepository,
          initialEmail: _email.text.trim(),
          isGuest: true,
          guestHasProgress: widget.guestHasProgress,
        ),
      ),
    );
  }

  String? _errorText() {
    final problem = _controller.problem;
    if (problem != null) {
      return switch (problem) {
        AccountFormProblem.missingFields =>
          'Enter an email, a password and a player name.',
        AccountFormProblem.nameTooLong =>
          'Player name: $maxDisplayNameLength characters at most.',
      };
    }
    final failure = _controller.failure;
    return failure == null
        ? null
        : describeAccountFailure(failure, detail: _controller.failureDetail);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Save your progress')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSubmitting;
            final error = _errorText();
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                Text(
                  'Your levels and history stay as they are. With an email '
                  'and a password you can play on another device, and your '
                  'player name can appear on the leaderboard.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        controller: _email,
                        enabled: !busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !busy,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        enabled: !busy,
                        maxLength: maxDisplayNameLength,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.nickname],
                        onSubmitted: (_) {
                          if (!busy) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Player name',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : _submit,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                if (_controller.failure == AccountFailure.emailAlreadyUsed)
                  TextButton(
                    onPressed: _signInInstead,
                    child: const Text('Sign in to that account instead'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
