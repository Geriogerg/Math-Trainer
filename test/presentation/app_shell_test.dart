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
    'le fondu de changement d\'onglet ne casse pas la préservation d\'état (commit F)',
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
      // Une seule frame : le fondu (200 ms) est encore en cours, exactement
      // ce qu'on veut vérifier — pas de pumpAndSettle qui masquerait un
      // crash pendant la transition elle-même.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Pas `find.text('Profile')` : ambigu avec le libellé de
      // l'onglet lui-même, présent en même temps dans l'arbre.
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
