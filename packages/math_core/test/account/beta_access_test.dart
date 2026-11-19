import 'package:math_core/account/account.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:test/test.dart';

class _MemoryStore implements BetaCodeStore {
  String? code;
  String? player;

  @override
  Future<String?> acceptedCode() async => code;
  @override
  Future<void> saveAcceptedCode(String value) async => code = value;
  @override
  Future<String?> redeemedFor() async => player;
  @override
  Future<void> markRedeemedFor(String playerId) async => player = playerId;
}

class _Codes implements BetaCodeRepository {
  BetaRedeemResult answer = BetaRedeemResult.redeemed;
  bool failing = false;
  final redeemed = <String>[];

  @override
  Future<BetaCodeStatus> status(String code) async => BetaCodeStatus.ok;

  @override
  Future<BetaRedeemResult> redeem(String code) async {
    if (failing) throw Exception('offline');
    redeemed.add(code);
    return answer;
  }
}

void main() {
  const guest = Account(id: 'g1', isAnonymous: true);
  late _MemoryStore store;
  late _Codes codes;

  setUp(() {
    store = _MemoryStore()..code = 'ABCD2345';
    codes = _Codes();
  });

  Future<BetaRedeemResult?> redeem(Account account) =>
      redeemDeviceBetaCode(store: store, codes: codes, account: account);

  test('normalizes like the server', () {
    expect(normalizeBetaCode(' ab-cd 23\t45 '), 'ABCD2345');
  });

  test('a new guest gets the device code, once', () async {
    expect(await redeem(guest), BetaRedeemResult.redeemed);
    expect(store.player, 'g1');
    expect(await redeem(guest), isNull);
    expect(codes.redeemed, ['ABCD2345']);
  });

  test('an email account, or no code on the device: nothing', () async {
    expect(await redeem(const Account(id: 'e1', email: 'a@b.c')), isNull);
    store.code = null;
    expect(await redeem(guest), isNull);
    expect(codes.redeemed, isEmpty);
  });

  test('a later guest on the same device redeems too', () async {
    await redeem(guest);
    expect(
      await redeem(const Account(id: 'g2', isAnonymous: true)),
      BetaRedeemResult.redeemed,
    );
    expect(store.player, 'g2');
  });

  test('a settled refusal is not asked again; a failure is', () async {
    codes.answer = BetaRedeemResult.full;
    expect(await redeem(guest), BetaRedeemResult.full);
    expect(await redeem(guest), isNull);

    store.player = null;
    codes.failing = true;
    expect(await redeem(guest), isNull);
    expect(store.player, isNull);
    codes.failing = false;
    codes.answer = BetaRedeemResult.redeemed;
    expect(await redeem(guest), BetaRedeemResult.redeemed);
  });
}
