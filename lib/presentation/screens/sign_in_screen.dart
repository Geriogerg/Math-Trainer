import 'package:material_ui/material_ui.dart';

import '../../core/domain/account/account_repository.dart';
import '../../core/domain/account/profile_repository.dart';
import '../../core/state/account_form_controller.dart';
import '../account_messages.dart';
import '../theme/app_theme.dart';

/// Sign in to an existing email account. For a guest, a clear warning
/// first (plan, section 6.3): the account replaces the guest on this
/// browser — the guest's games stay on the device but are no longer shown,
/// and the two histories are never merged. On success the whole stack
/// closes: `AuthGate` has already switched to the signed-in account.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.accountRepository,
    required this.profileRepository,
    required this.isGuest,
    this.guestHasProgress = false,
    this.initialEmail = '',
  });

  final AccountRepository accountRepository;
  final ProfileRepository profileRepository;
  final bool isGuest;

  /// The guest has played at least one game here: what the warning is about.
  final bool guestHasProgress;
  final String initialEmail;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final AccountFormController _controller = AccountFormController(
    accounts: widget.accountRepository,
    profiles: widget.profileRepository,
  );
  late final _email = TextEditingController(text: widget.initialEmail);
  final _password = TextEditingController();

  bool get _replacesGuestProgress => widget.isGuest && widget.guestHasProgress;

  @override
  void dispose() {
    _controller.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await _controller.signIn(
      email: _email.text,
      password: _password.text,
    );
    if (!mounted || !ok) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String? _errorText() {
    if (_controller.problem == AccountFormProblem.missingFields) {
      return 'Enter your email and password.';
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
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSubmitting;
            final error = _errorText();
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                if (_replacesGuestProgress) ...[
                  // Not colour alone (rule 14): an icon and words carry it.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your guest progress on this browser will be '
                          'replaced by this account. It stays on this device '
                          'but will no longer be shown, and the two histories '
                          'are never merged. To keep it, go back and save your '
                          'progress with a new email instead.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
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
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!busy) _submit();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Password',
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
                      : Text(
                          _replacesGuestProgress
                              ? 'Sign in and replace guest progress'
                              : 'Sign in',
                        ),
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
              ],
            );
          },
        ),
      ),
    );
  }
}
