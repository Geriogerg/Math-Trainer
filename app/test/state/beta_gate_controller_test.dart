import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:math_trainer/core/state/beta_gate_controller.dart';

class _Store implements BetaCodeStore {
  String? code;
  @override
  Future<String?> acceptedCode() async => code;
  @override
  Future<void> saveAcceptedCode(String value) async => code = value;
  @override
  Future<String?> redeemedFor() async => null;
  @override
  Future<void> markRedeemedFor(String playerId) async {}
}

class _Codes implements BetaCodeRepository {
  _Codes(this.answer);
  final Future<BetaCodeStatus> Function() answer;
  final asked = <String>[];
  @override
  Future<BetaCodeStatus> status(String code) {
    asked.add(code);
    return answer();
  }

  @override
  Future<BetaRedeemResult> redeem(String code) => throw UnimplementedError();
}

void main() {
  Future<(BetaGateController, _Store, _Codes, List<int>)> make(
    Future<BetaCodeStatus> Function() answer,
  ) async {
    final store = _Store();
    final codes = _Codes(answer);
    final accepted = <int>[];
    final controller = BetaGateController(
      codes: codes,
      store: store,
      onAccepted: () => accepted.add(1),
    );
    addTearDown(controller.dispose);
    return (controller, store, codes, accepted);
  }

  test('blank: says so without asking the server', () async {
    final (controller, _, codes, accepted) = await make(
      () async => BetaCodeStatus.ok,
    );
    await controller.submit('  - ');
    expect(controller.problem, BetaGateProblem.empty);
    expect(codes.asked, isEmpty);
    expect(accepted, isEmpty);
  });

  for (final (status, problem) in [
    (BetaCodeStatus.unknown, BetaGateProblem.unknown),
    (BetaCodeStatus.full, BetaGateProblem.full),
    (BetaCodeStatus.disabled, BetaGateProblem.disabled),
  ]) {
    test('${status.name}: ${problem.name}, nothing stored', () async {
      final (controller, store, _, accepted) = await make(() async => status);
      await controller.submit('abcd2345');
      expect(controller.problem, problem);
      expect(controller.checking, isFalse);
      expect(store.code, isNull);
      expect(accepted, isEmpty);
    });
  }

  test('offline: its own message, can try again', () async {
    final (controller, _, _, accepted) = await make(
      () async => throw Exception('offline'),
    );
    await controller.submit('ABCD2345');
    expect(controller.problem, BetaGateProblem.offline);
    expect(accepted, isEmpty);
  });

  test('ok: normalized code stored, then the gate opens', () async {
    final (controller, store, codes, accepted) = await make(
      () async => BetaCodeStatus.ok,
    );
    await controller.submit(' abcd-2345 ');
    expect(codes.asked, ['ABCD2345']);
    expect(store.code, 'ABCD2345');
    expect(accepted, [1]);
    expect(controller.problem, isNull);
  });
}
