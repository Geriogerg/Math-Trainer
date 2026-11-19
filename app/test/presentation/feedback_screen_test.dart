import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/feedback/feedback.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

class _Repository implements FeedbackRepository {
  bool failing = true;
  final sent = <(String, String)>[];

  @override
  Future<FeedbackOutcome> send({
    required String message,
    required String appVersion,
  }) async {
    if (failing) throw Exception('offline');
    sent.add((message, appVersion));
    return FeedbackOutcome.sent;
  }
}

void main() {
  Future<void> pumpProfile(
    WidgetTester tester,
    FeedbackRepository? feedback,
  ) async {
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
              feedbackRepository: feedback,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('from Profile: a failed send keeps the text, then it goes', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpProfile(tester, repository);

    await tester.tap(find.text('Send feedback'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Write something first.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Roots feel slow.');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Not sent: no connection. Try again.'), findsOneWidget);
    expect(find.text('Roots feel slow.'), findsOneWidget);

    repository.failing = false;
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Thank you — it was sent.'), findsOneWidget);
    expect(repository.sent, [('Roots feel slow.', appVersion)]);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Send feedback'), findsOneWidget);
  });

  testWidgets('no feedback repository: no button', (tester) async {
    await pumpProfile(tester, null);
    expect(find.text('Send feedback'), findsNothing);
  });
}
