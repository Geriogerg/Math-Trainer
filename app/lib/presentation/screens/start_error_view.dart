import 'package:material_ui/material_ui.dart';

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
    AccountFailure.network =>
      'No connection. Math Trainer needs the internet the first time it '
          'opens; after that it also plays offline.',
    AccountFailure.rateLimited =>
      'Too many new players from this network right now. Try again in a '
          'few minutes.',
    AccountFailure.invalidCredentials ||
    AccountFailure.emailNotConfirmed ||
    AccountFailure.emailAlreadyUsed ||
    AccountFailure.weakPassword ||
    AccountFailure.invalidInput ||
    AccountFailure.unknown => 'The game could not start. Try again.',
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
              "Couldn't start",
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
            AppButton.primary(onPressed: onRetry, label: 'Try again'),
          ],
        ),
      ),
    );
  }
}
