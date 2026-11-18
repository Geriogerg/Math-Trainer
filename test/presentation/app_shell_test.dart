import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/presentation/screens/app_shell.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

void main() {
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
      await tester.pump();

      await tester.tap(find.text('Multiplication'));
      await tester.pump();

      await tester.tap(find.text('Profile'));
      // A single frame: the fade (200 ms) is still running, exactly what we
      // want to check — no pumpAndSettle that would hide a crash during the
      // transition itself.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Not `find.text('Profile')`: ambiguous with the tab's own label,
      // present in the tree at the same time.
      expect(find.text('By operation'), findsOneWidget);

      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final chip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Multiplication'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(chip.selected, isTrue);
    },
  );
}
