import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

/// Phase 4 commit 5: Profile's "Weak spots" block.
void main() {
  Future<void> pumpProfile(
    WidgetTester tester,
    InMemorySessionRepository repository,
  ) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: repository,
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the worst facts, with a Practice button', (tester) async {
    final repository = InMemorySessionRepository();
    await repository.recordSession(
      session: PersistedSession(
        id: 'g',
        playerId: 'test-player',
        seed: 1,
        enabledTypes: const {ExerciseType.multiplication},
        exerciseCount: 4,
        totalScore: 0,
        levels: {ExerciseType.multiplication: Level.zero},
        createdAt: DateTime.utc(2026, 8, 8),
      ),
      answers: [
        for (final i in [0, 1])
          PersistedAnswer(
            id: 'a$i',
            sessionId: 'g',
            exerciseType: 'arithmetic',
            operationType: 'multiplication',
            operands: const {'operandA': 7, 'operandB': 8},
            submittedValue: 54,
            isCorrect: false,
            elapsedMs: 3000,
            createdAt: DateTime.utc(2026, 8, 8),
          ),
      ],
      levelUpdates: const {},
    );
    await pumpProfile(tester, repository);
    expect(find.text('Weak spots'), findsOneWidget);
    expect(find.text('2 of 2 missed'), findsOneWidget);
    expect(find.byKey(const ValueKey('practise-weak-spots')), findsOneWidget);
  });

  testWidgets('none yet for a new player', (tester) async {
    await pumpProfile(tester, InMemorySessionRepository());
    expect(find.text('Weak spots'), findsOneWidget);
    expect(find.text('None yet'), findsOneWidget);
    expect(find.byKey(const ValueKey('practise-weak-spots')), findsNothing);
  });
}
