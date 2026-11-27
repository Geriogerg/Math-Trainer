import 'package:material_ui/material_ui.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';
import '../../core/state/account_form_controller.dart';
import '../kit/kit.dart';
import '../strings/account_messages.dart';
import '../strings/strings.dart';
import '../theme/app_theme.dart';

/// "Forgot password?" (Phase 6c commit 4, plan v4.1; review B3): the email
/// of the account, then a link sent to it — with Supabase's own sender
/// until the owner's exists. The link signs the player in on whatever
/// device opens it; the gate then asks for a new password
/// ([SetPasswordScreen]).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.accountRepository,
    required this.profileRepository,
    this.initialEmail = '',
  });

  final AccountRepository accountRepository;
  final ProfileRepository profileRepository;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AccountFormController _controller = AccountFormController(
    accounts: widget.accountRepository,
    profiles: widget.profileRepository,
  );
  late final _email = TextEditingController(text: widget.initialEmail);

  /// The address the link went to, once sent.
  String? _sentTo;

  @override
  void dispose() {
    _controller.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (await _controller.requestPasswordReset(email: email) && mounted) {
      setState(() => _sentTo = email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.account.resetTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSubmitting;
            final sentTo = _sentTo;
            final failure = _controller.failure;
            final error = _controller.problem != null
                ? strings.account.resetMissing
                : failure == null
                ? null
                : describeAccountFailure(
                    failure,
                    detail: _controller.failureDetail,
                  );
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                if (sentTo != null) ...[
                  Text(
                    strings.account.resetSent(sentTo),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  AppButton.primary(
                    onPressed: () => Navigator.of(context).pop(),
                    label: strings.account.done,
                  ),
                ] else ...[
                  Text(
                    strings.account.resetDetail,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    onSubmitted: (_) {
                      if (!busy) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: strings.account.email,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton.primary(
                    onPressed: _submit,
                    busy: busy,
                    label: strings.account.sendLink,
                  ),
                ],
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

/// A new password, after a recovery link signed the player in (Phase 6c
/// commit 4). Pops `true` once it is set.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({
    super.key,
    required this.accountRepository,
    required this.profileRepository,
  });

  final AccountRepository accountRepository;
  final ProfileRepository profileRepository;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  late final AccountFormController _controller = AccountFormController(
    accounts: widget.accountRepository,
    profiles: widget.profileRepository,
  );
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _controller.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (await _controller.setPassword(password: _password.text) && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.account.newPasswordTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSubmitting;
            final failure = _controller.failure;
            final error = _controller.problem != null
                ? strings.account.newPasswordMissing
                : failure == null
                ? null
                : describeAccountFailure(
                    failure,
                    detail: _controller.failureDetail,
                  );
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                Text(
                  strings.account.newPasswordDetail,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _password,
                  enabled: !busy,
                  obscureText: !_showPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onSubmitted: (_) {
                    if (!busy) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: strings.account.newPassword,
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
                const SizedBox(height: 16),
                AppButton.primary(
                  onPressed: _submit,
                  busy: busy,
                  label: strings.account.save,
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
