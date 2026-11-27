import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../composition_root.dart';
import 'package:math_core/account/account.dart';
import 'package:math_core/account/account_repository.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import '../../core/state/beta_gate_controller.dart';
import 'app_shell.dart';
import 'beta_gate_screen.dart';
import 'sign_in_screen.dart';
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
///
/// During the invite-only beta (`AppEnvironment.betaCodes`, Phase 3a commit
/// 3), a device that never passed the gate is asked for a code first; the
/// guest it then creates is tied to that code.
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

  /// Set while the beta gate asks this device for a code.
  BetaGateController? _gate;

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
    // A guest replaced by another account on this device can never come
    // back: its hidden games go after 30 days (Phase 2 commit 11).
    final previous = _account;
    if (previous != null && previous.isAnonymous && account != null) {
      widget.environment.abandonedGuestStore
          .record(previous.id, DateTime.now().toUtc())
          .ignore();
    }
    setState(() {
      _isResolved = true;
      _account = account;
      _playerEnvironment = null;
    });
    if (account == null) {
      _startOrAskCode().ignore();
      return;
    }
    _closeGate();
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
    // Whatever was played offline (or before a server existed) goes now;
    // then the server's levels replace the local ones if they differ (Phase
    // 6b commit 5: a new device shows them at once), and are read ahead of
    // the first game (Phase 5.1 commit 1) — both skipped if sessions still
    // wait (offline, server asleep).
    final ahead = playerEnvironment.serverLevelsAhead;
    switch (playerEnvironment.uploadQueue) {
      case final queue?:
        queue
            .flush()
            .then((_) => adoptServerLevelsAtSignIn(playerEnvironment))
            .then((_) => ahead?.start())
            .catchError((Object _) {})
            .ignore();
      case null:
        ahead?.start().ignore();
    }
    if (widget.environment.betaCodes case final codes?) {
      redeemDeviceBetaCode(
        store: widget.environment.betaCodeStore,
        codes: codes,
        account: account,
      ).ignore();
    }
    deleteAbandonedGuests(
      store: widget.environment.abandonedGuestStore,
      repository: widget.environment.repository,
      now: DateTime.now().toUtc(),
    ).ignore();
  }

  /// The beta gate first, unless the build has none or this device passed
  /// it already (a sign-out of an email account is not a new visitor).
  Future<void> _startOrAskCode() async {
    final codes = widget.environment.betaCodes;
    if (codes != null &&
        await widget.environment.betaCodeStore.acceptedCode() == null) {
      if (!mounted || _account != null) return;
      setState(() {
        _gate ??= BetaGateController(
          codes: codes,
          store: widget.environment.betaCodeStore,
          onAccepted: _onCodeAccepted,
        );
      });
      return;
    }
    _startAnonymousPlayer();
  }

  void _onCodeAccepted() {
    _closeGate();
    _startAnonymousPlayer();
  }

  void _closeGate() {
    final gate = _gate;
    if (gate == null) return;
    setState(() => _gate = null);
    // After the frame that removes the screen listening to it.
    WidgetsBinding.instance.addPostFrameCallback((_) => gate.dispose());
  }

  /// An existing account needs no code: signing in emits it on
  /// `authState`, which closes the gate.
  void _signInFromGate() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SignInScreen(
          accountRepository: _accounts,
          profileRepository: widget.environment.profileRepository,
          isGuest: false,
        ),
      ),
    );
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
    _gate?.dispose();
    _playerEnvironment?.uploadQueue?.dispose();
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final playerEnvironment = _playerEnvironment;
    final startFailure = _startFailure;
    final gate = _gate;
    if (account == null && gate != null) {
      return BetaGateScreen(controller: gate, onSignIn: _signInFromGate);
    }
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
