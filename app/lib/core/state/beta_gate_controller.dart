import 'package:flutter/foundation.dart';
import 'package:math_core/account/beta_access.dart';

/// Why a typed code did not open the gate.
enum BetaGateProblem { empty, unknown, full, disabled, offline }

/// The gate screen's state (Phase 3a commit 3): checks a code with the
/// server, remembers it on the device once accepted, then lets
/// `AuthGate` create the guest ([onAccepted]).
class BetaGateController extends ChangeNotifier {
  BetaGateController({
    required this.codes,
    required this.store,
    required this.onAccepted,
  });

  final BetaCodeRepository codes;
  final BetaCodeStore store;
  final VoidCallback onAccepted;

  bool _checking = false;
  BetaGateProblem? _problem;
  bool _disposed = false;

  bool get checking => _checking;
  BetaGateProblem? get problem => _problem;

  Future<void> submit(String raw) async {
    if (_checking) return;
    final code = normalizeBetaCode(raw);
    if (code.isEmpty) {
      _set(problem: BetaGateProblem.empty);
      return;
    }
    _set(checking: true);
    final BetaCodeStatus status;
    try {
      status = await codes.status(code);
    } on Exception catch (_) {
      _set(problem: BetaGateProblem.offline);
      return;
    }
    switch (status) {
      case BetaCodeStatus.ok:
        await store.saveAcceptedCode(code);
        _set();
        onAccepted();
      case BetaCodeStatus.unknown:
        _set(problem: BetaGateProblem.unknown);
      case BetaCodeStatus.full:
        _set(problem: BetaGateProblem.full);
      case BetaCodeStatus.disabled:
        _set(problem: BetaGateProblem.disabled);
    }
  }

  void _set({bool checking = false, BetaGateProblem? problem}) {
    if (_disposed) return;
    _checking = checking;
    _problem = problem;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
