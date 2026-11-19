import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/account/beta_access.dart';
import 'package:math_trainer/core/state/beta_gate_controller.dart';
import 'package:math_trainer/presentation/screens/beta_gate_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

class _Store implements BetaCodeStore {
  @override
  Future<String?> acceptedCode() async => null;
  @override
  Future<void> saveAcceptedCode(String value) async {}
  @override
  Future<String?> redeemedFor() async => null;
  @override
  Future<void> markRedeemedFor(String playerId) async {}
}

class _Unknown implements BetaCodeRepository {
  @override
  Future<BetaCodeStatus> status(String code) async => BetaCodeStatus.unknown;
  @override
  Future<BetaRedeemResult> redeem(String code) => throw UnimplementedError();
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('beta gate, a wrong code — $name', (tester) async {
      await setGoldenSurfaceSize(tester);
      final controller = BetaGateController(
        codes: _Unknown(),
        store: _Store(),
        onAccepted: () {},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: BetaGateScreen(controller: controller, onSignIn: () {}),
        ),
      );
      await tester.enterText(find.byType(TextField), 'K7QP-2X9M');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/beta_gate_$name.png'),
      );
    });
  }
}
