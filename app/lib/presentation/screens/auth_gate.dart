import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'app_shell.dart';
import 'start_error_view.dart';

/// The app's entry gate — **anonymous-first** (plan, section 6.3; Phase 1
/// commit 4). Nobody fills a form to play: when no session exists, the gate
/// silently creates an anonymous player and goes straight to the game. The
/// Supabase session is persisted locally, so every later launch gets the
/// same player back without network; only the very first visit (or after a
/// sign-out of an email account) needs it. If that first anonymous sign-in
/// fails, a retry screen says why.
///
/// Once signed in, everything (levels, history) is bound to the account id,
/// not the device (`environmentForAccount`) — and linking an email later
/// keeps that id.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.environment, this.onToggleTheme});

  final AppEnvironment environment;
  final VoidCallback? onToggleTheme;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<Account?> _authSubscription;

  /// `false` until the local session is resolved (no network needed) — no
  /// anonymous sign-in before that, or a returning player would get a
  /// second, empty account instead of their own.
  bool _isResolved = false;
  Account? _account;

  /// Environment of the signed-in account (`environmentForAccount`), `null`
  /// until adopting the device's games has completed — loading is shown
  /// meanwhile, so that no screen reads a still incomplete history.
  AppEnvironment? _playerEnvironment;

  /// The anonymous sign-in in flight — at most one at a time, whatever the
  /// number of `null` states the auth stream emits meanwhile.
  Future<void>? _anonymousSignIn;
  AccountFailure? _startFailure;

  AccountRepository get _accounts => widget.environment.accountRepository;

  @override
  void initState() {
    super.initState();
    // A single subscription, not a `StreamBuilder`: `authState` returns a
    // new `Stream` on each read, and resubscribing would go through the
    // loading state again, unmounting then recreating `AppShell` (current
    // tab and state lost) on every rebuild of the parent.
    _authSubscription = _accounts.authState.listen(_onAccountChanged);
  }

  Future<void> _onAccountChanged(Account? account) async {
    if (_isResolved && account?.id == _account?.id) {
      // Same player, but linking may have changed email/anonymity.
      if (account != _account) setState(() => _account = account);
      return;
    }
    _playerEnvironment?.uploadQueue?.dispose();
    setState(() {
      _isResolved = true;
      _account = account;
      _playerEnvironment = null;
    });
    if (account == null) {
      _startAnonymousPlayer();
      return;
    }
    final playerEnvironment = await environmentForAccount(
      widget.environment,
      account,
    );
    // Signed out or switched account during adoption: stale result, the
    // call triggered by the new state takes over.
    if (!mounted || _account?.id != account.id) {
      playerEnvironment.uploadQueue?.dispose();
      return;
    }
    setState(() => _playerEnvironment = playerEnvironment);
    // Whatever was played offline (or before a server existed) goes now.
    playerEnvironment.uploadQueue?.flush().ignore();
  }

  void _startAnonymousPlayer() {
    if (_anonymousSignIn != null) return;
    setState(() => _startFailure = null);
    _anonymousSignIn = _accounts
        .signInAnonymously()
        // Success needs nothing here: `authState` emits the new account,
        // which `_onAccountChanged` handles like any sign-in.
        .then<void>((_) {})
        .catchError((Object error) {
          if (!mounted) return;
          setState(() {
            _startFailure = error is AccountException
                ? error.failure
                : AccountFailure.unknown;
          });
        })
        .whenComplete(() => _anonymousSignIn = null);
  }

  @override
  void dispose() {
    _playerEnvironment?.uploadQueue?.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final playerEnvironment = _playerEnvironment;
    final startFailure = _startFailure;
    if (_isResolved && account == null && startFailure != null) {
      return Scaffold(
        body: SafeArea(
          child: StartErrorView(
            failure: startFailure,
            onRetry: _startAnonymousPlayer,
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
