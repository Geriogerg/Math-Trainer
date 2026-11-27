import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import '../kit/kit.dart';

import 'package:math_core/account/account_exception.dart';
import '../theme/app_theme.dart';

/// Shown when the very first launch could not create the anonymous player
/// (`AuthGate`). Says why in the player's terms and offers to try again —
/// the only screen before the game that asks anything of the player.
class StartErrorView extends StatelessWidget {
  const StartErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final AccountFailure failure;
  final VoidCallback onRetry;

  static String messageFor(AccountFailure failure) => switch (failure) {
    AccountFailure.network => strings.account.startOffline,
    AccountFailure.rateLimited => strings.account.startRateLimited,
    AccountFailure.humanCheck => strings.account.startHumanCheck,
    AccountFailure.invalidCredentials ||
    AccountFailure.emailNotConfirmed ||
    AccountFailure.emailAlreadyUsed ||
    AccountFailure.weakPassword ||
    AccountFailure.invalidInput ||
    AccountFailure.unknown => strings.account.startUnknown,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: theme.extension<AppMetrics>()!.rootPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.account.couldNotStart,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              messageFor(failure),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton.primary(
              onPressed: onRetry,
              label: strings.account.tryAgain,
            ),
          ],
        ),
      ),
    );
  }
}
