import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/leveling/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/presentation/screens/progress_screen.dart';

void main() {
  testWidgets('affiche les 7 types, un niveau connu et "Non joué" pour les autres', (
    WidgetTester tester,
  ) async {
    final repository = InMemorySessionRepository();
    await repository.recordSession(
      session: PersistedSession(
        id: 'session-1',
        playerId: 'test-player',
        seed: 1,
        enabledTypes: const {ExerciseType.addition},
        exerciseCount: 8,
        totalScore: 80,
        levels: const {ExerciseType.addition: 1},
        createdAt: DateTime.utc(2026, 8, 8),
      ),
      answers: const [],
      levelUpdates: {
        ExerciseType.addition: LevelCacheEntry(
          level: 42,
          sessionsPlayed: 1,
          updatedAt: DateTime.utc(2026, 8, 8),
        ),
      },
    );
    final environment = AppEnvironment(repository: repository, playerId: 'test-player');

    await tester.pumpWidget(
      MaterialApp(home: ProgressScreen(environment: environment)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niveau 42'), findsOneWidget);
    expect(find.text('Non joué'), findsNWidgets(6));
    for (final type in ExerciseType.values) {
      expect(find.text(_labelFor(type)), findsOneWidget);
    }
  });
}

String _labelFor(ExerciseType type) => switch (type) {
  ExerciseType.addition => 'Addition',
  ExerciseType.subtraction => 'Soustraction',
  ExerciseType.multiplication => 'Multiplication',
  ExerciseType.division => 'Division',
  ExerciseType.power => 'Puissances',
  ExerciseType.squareRoot => 'Racines carrées',
  ExerciseType.percentage => 'Pourcentages',
};
