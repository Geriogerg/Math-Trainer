import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import '../kit/kit.dart';

import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/profile_repository.dart';
import '../../core/state/account_form_controller.dart';
import 'package:math_trainer/presentation/strings/account_messages.dart';
import '../theme/app_theme.dart';
import 'sign_in_screen.dart';
import 'legal_screen.dart';

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

  /// The password shown as typed (review m17), hidden by default.
  bool _showPassword = false;

  /// "I am 15 or older" (Phase 6c commit 2), unticked until the player
  /// ticks it.
  bool _ageConfirmed = false;
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
      ageConfirmed: _ageConfirmed,
      // The account's emails in the interface's language (Phase 6d).
      language: appLanguage.value.code,
    );
    if (!mounted || outcome == SaveProgressOutcome.failed) return;
    // The link waits in the inbox: this screen says so (and can send it
    // again) until Done.
    if (outcome == SaveProgressOutcome.confirmationPending) return;
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
        AccountFormProblem.missingFields => strings.account.saveProgressMissing,
        AccountFormProblem.invalidName => describeNameProblem(
          _controller.nameProblem!,
        ),
        AccountFormProblem.ageNotConfirmed => strings.account.ageMissing,
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
      appBar: AppBar(title: Text(strings.account.saveProgress)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSubmitting;
            final error = _errorText();
            if (_controller.pendingEmail case final email?) {
              return _CheckInbox(
                email: email,
                busy: busy,
                resent: _controller.resent,
                error: error,
                onResend: _controller.resendConfirmation,
                onDone: () => Navigator.of(
                  context,
                ).pop(SaveProgressOutcome.confirmationPending),
              );
            }
            return ListView(
              padding: theme.extension<AppMetrics>()!.rootPadding,
              children: [
                Text(
                  strings.account.saveProgressDetail,
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
                        decoration: InputDecoration(
                          labelText: strings.account.email,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        enabled: !busy,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
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
                        decoration: InputDecoration(
                          labelText: strings.account.playerName,
                        ),
                      ),
                    ],
                  ),
                ),
                // The minimum age, declared (plan 6.3; review B1).
                CheckboxListTile(
                  value: _ageConfirmed,
                  onChanged: busy
                      ? null
                      : (v) => setState(() => _ageConfirmed = v ?? false),
                  title: Text(strings.account.ageBox),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
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
                if (_controller.failure == AccountFailure.emailAlreadyUsed)
                  AppButton.secondary(
                    onPressed: _signInInstead,
                    label: strings.account.signInInstead,
                  ),
                const SizedBox(height: 16),
                // What happens to what is given here (Phase 6c commit 2).
                LegalLinks(
                  privacyLabel: strings.account.privacyPolicy,
                  noticeLabel: strings.account.legalNotice,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The link is in the inbox (Phase 6c commit 3): where it went, what
/// happens meanwhile, send it again, Done.
class _CheckInbox extends StatelessWidget {
  const _CheckInbox({
    required this.email,
    required this.busy,
    required this.resent,
    required this.error,
    required this.onResend,
    required this.onDone,
  });

  final String email;
  final bool busy;
  final bool resent;
  final String? error;
  final VoidCallback onResend;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: theme.extension<AppMetrics>()!.rootPadding,
      children: [
        Semantics(
          header: true,
          child: Text(
            strings.account.checkInbox,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.account.linkSent(email),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        AppButton.primary(onPressed: onDone, label: strings.account.done),
        const SizedBox(height: 8),
        AppButton.secondary(
          onPressed: busy ? null : onResend,
          busy: busy,
          label: strings.account.sendAgain,
        ),
        if (resent && error == null) Caption(strings.account.sentAgain),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
