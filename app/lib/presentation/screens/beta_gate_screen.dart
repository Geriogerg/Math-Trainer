import 'package:material_ui/material_ui.dart';

import '../kit/kit.dart';

import '../../core/state/beta_gate_controller.dart';
import '../theme/app_theme.dart';
import 'privacy_screen.dart';

/// The invite-only beta's door (Phase 3a commit 3): shown by `AuthGate`
/// on a device with no session and no accepted code, before any account
/// exists. Someone with an account signs in instead, without a code.
class BetaGateScreen extends StatefulWidget {
  const BetaGateScreen({
    super.key,
    required this.controller,
    required this.onSignIn,
  });

  final BetaGateController controller;
  final VoidCallback onSignIn;

  static String messageFor(BetaGateProblem problem) => switch (problem) {
    BetaGateProblem.empty => 'Enter the code from your invitation.',
    BetaGateProblem.unknown =>
      'This code is not valid. Check it against your invitation.',
    BetaGateProblem.full => 'This code has already been used.',
    BetaGateProblem.disabled => 'This code is no longer active.',
    BetaGateProblem.offline => 'No connection. Check it and try again.',
  };

  @override
  State<BetaGateScreen> createState() => _BetaGateScreenState();
}

class _BetaGateScreenState extends State<BetaGateScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() => widget.controller.submit(_code.text).ignore();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: theme.extension<AppMetrics>()!.rootPadding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  final checking = widget.controller.checking;
                  final problem = widget.controller.problem;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Math Trainer',
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'The beta is invite-only. Enter the code from your '
                        'invitation.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _code,
                        enabled: !checking,
                        autofocus: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Invitation code',
                          errorText: problem == null
                              ? null
                              : BetaGateScreen.messageFor(problem),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppButton.primary(
                        onPressed: checking ? null : _submit,
                        label: checking ? 'Checking…' : 'Continue',
                      ),
                      const SizedBox(height: 8),
                      AppButton.secondary(
                        onPressed: checking ? null : widget.onSignIn,
                        label: 'I already have an account',
                      ),
                      // Before giving any data (Phase 3a commit 4).
                      AppButton.secondary(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PrivacyScreen(),
                          ),
                        ),
                        label: 'Privacy',
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
