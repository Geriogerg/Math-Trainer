import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer/presentation/kit/kit.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

void main() {
  // `PlayTab` reads the remembered selection before it draws (no flash of
  // the default selection).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'the tab change fade does not break state preservation (commit F)',
    (tester) async {
      final environment = AppEnvironment(
        repository: InMemorySessionRepository(),
        playerId: 'test-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: AppShell(environment: environment),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(RegExp('^Multiplication, ')));
      await tester.pump();

      await tester.tap(find.text('Profile'));
      // A single frame: the fade (200 ms) is still running, exactly what we
      // want to check — no pumpAndSettle that would hide a crash during the
      // transition itself.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Not `find.text('Profile')`: ambiguous with the tab's own label,
      // present in the tree at the same time.
      expect(find.textContaining('30-day change'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Play'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final button = tester.widget<OperationButton>(
        find.byWidgetPredicate(
          (w) => w is OperationButton && w.type == ExerciseType.multiplication,
        ),
      );
      expect(button.selected, isTrue);
    },
  );
}
