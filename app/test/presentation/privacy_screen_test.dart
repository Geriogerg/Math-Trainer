import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/privacy_screen.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

void main() {
  String allText() => [
    for (final (title, points) in PrivacyScreen.sections) ...[title, ...points],
  ].join('\n');

  test('says what, where, why, who and how to delete', () {
    expect(PrivacyScreen.sections.map((s) => s.$1), [
      'What is stored',
      'Where',
      'Why',
      'Who sees what',
      'Deleting it',
    ]);
    // The button it names exists with these words (profile_screen.dart).
    expect(allText(), contains('“Delete my data”'));
    expect(allText(), contains('“Delete my account”'));
  });

  test('the guest retention it states is the one the code applies', () {
    expect(
      allText(),
      contains('unused for ${abandonedGuestRetention.inDays} days'),
    );
  });

  testWidgets('reachable from Profile', (tester) async {
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'p',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('What is stored'), findsOneWidget);
    expect(find.text('Deleting it'), findsOneWidget);
  });
}
