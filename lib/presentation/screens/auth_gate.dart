import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import '../../core/domain/account/account.dart';
import 'app_shell.dart';
import 'auth_form.dart';

/// The app's entry gate — mandatory sign-in (`doc/online.md`, step 6 slice
/// 2; replaced by anonymous-first in Phase 1). The Supabase session is
/// persisted locally: a player already signed in gets their account back
/// without network at the next launch; only a first launch (never signed in
/// on this device) or an explicit sign-out shows the form. Once signed in,
/// everything that follows (levels, history) is bound to the account, not
/// the device (`environmentForAccount`).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<Account?> _authSubscription;

  /// `false` until the local session is resolved (no network needed) —
  /// never show the form at this stage, it would make the gate flicker for
  /// a player already signed in.
  bool _isResolved = false;
  Account? _account;

  /// Environment of the signed-in account (`environmentForAccount`), `null`
  /// until adopting the device's games has completed — loading is shown
  /// meanwhile, so that no screen reads a still incomplete history.
  AppEnvironment? _playerEnvironment;

  @override
  void initState() {
    super.initState();
    // A single subscription, not a `StreamBuilder`: `authState` returns a
    // new `Stream` on each read, and resubscribing would go through the
    // loading state again, unmounting then recreating `AppShell` (current
    // tab and state lost) on every rebuild of the parent.
    _authSubscription = widget.environment.accountRepository.authState.listen(
      _onAccountChanged,
    );
  }

  Future<void> _onAccountChanged(Account? account) async {
    if (_isResolved && account?.id == _account?.id) return;
    setState(() {
      _isResolved = true;
      _account = account;
      _playerEnvironment = null;
    });
    if (account == null) return;
    final playerEnvironment = await environmentForAccount(
      widget.environment,
      account,
    );
    // Signed out or switched account during adoption: stale result, the
    // call triggered by the new state takes over.
    if (!mounted || _account?.id != account.id) return;
    setState(() => _playerEnvironment = playerEnvironment);
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final playerEnvironment = _playerEnvironment;
    if (_isResolved && account == null) {
      return Scaffold(
        body: SafeArea(
          child: AuthForm(
            accountRepository: widget.environment.accountRepository,
          ),
        ),
      );
    }
    if (account == null || playerEnvironment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return AppShell(
      // Another account starts from a fresh `AppShell`: no state (displayed
      // level, Profile tab) survives from one player to the next.
      key: ValueKey(account.id),
      environment: playerEnvironment,
      onToggleTheme: widget.onToggleTheme,
    );
  }
}
