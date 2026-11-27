import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import '../kit/kit.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';
import '../../core/state/account_form_controller.dart';
import 'package:math_trainer/presentation/strings/account_messages.dart';
import '../theme/app_theme.dart';
import 'password_screens.dart';

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

  /// The password shown as typed (review m17), hidden by default.
  bool _showPassword = false;

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
      return strings.account.signInMissing;
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
      appBar: AppBar(title: Text(strings.account.signIn)),
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
                          strings.account.guestReplaced,
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
                        decoration: InputDecoration(
                          labelText: strings.account.email,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !busy,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (!busy) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: strings.account.password,
                          // Review m17: no way to check what was typed.
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            tooltip: _showPassword
                                ? strings.account.hidePassword
                                : strings.account.showPassword,
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppButton.primary(
                  onPressed: _submit,
                  busy: busy,
                  label: _replacesGuestProgress
                      ? strings.account.signInReplacing
                      : strings.account.signIn,
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
                const SizedBox(height: 8),
                // Phase 6c commit 4 (review B3): without it a forgotten
                // password lost the account.
                AppButton.secondary(
                  onPressed: busy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(
                              accountRepository: widget.accountRepository,
                              profileRepository: widget.profileRepository,
                              initialEmail: _email.text.trim(),
                            ),
                          ),
                        ),
                  label: strings.account.forgotPassword,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
