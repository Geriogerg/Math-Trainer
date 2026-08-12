import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/progress_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

/// Échoue tant que [shouldFail] est vrai, réussit ensuite — simule un
/// réseau/disque qui se rétablit, pour tester le bouton « Réessayer ».
class _FlakySessionRepository implements SessionRepository {
  bool shouldFail = true;

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) async {
    if (shouldFail) throw Exception('échec simulé');
    return {
      ExerciseType.addition: LevelCacheEntry(
        level: 7,
        sessionsPlayed: 1,
        updatedAt: DateTime.utc(2026, 8, 8),
      ),
    };
  }

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw UnimplementedError();

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) => throw UnimplementedError();

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw UnimplementedError();

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      throw UnimplementedError();

  @override
  Future<List<PersistedSession>> sessionsSince(String playerId, DateTime since) =>
      throw UnimplementedError();
}

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
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProgressScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Niveau 42'), findsOneWidget);
    expect(find.text('Non joué'), findsNWidgets(6));
    for (final type in ExerciseType.values) {
      expect(find.text(_labelFor(type)), findsOneWidget);
    }
  });

  testWidgets('un repository qui échoue affiche un message et un bouton Réessayer', (
    WidgetTester tester,
  ) async {
    final repository = _FlakySessionRepository();
    final environment = AppEnvironment(repository: repository, playerId: 'test-player');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProgressScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger la progression.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Réessayer'), findsOneWidget);
  });

  testWidgets('Réessayer relance la lecture et affiche la progression si elle réussit', (
    WidgetTester tester,
  ) async {
    final repository = _FlakySessionRepository();
    final environment = AppEnvironment(repository: repository, playerId: 'test-player');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(body: ProgressScreen(environment: environment)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger la progression.'), findsOneWidget);

    repository.shouldFail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Réessayer'));
    await tester.pumpAndSettle();

    expect(find.text('Impossible de charger la progression.'), findsNothing);
    expect(find.text('Niveau 7'), findsOneWidget);
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
