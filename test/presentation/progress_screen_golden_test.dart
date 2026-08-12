import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/progress_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import 'golden_test_utils.dart';

/// Niveaux fixes pour deux types, les cinq autres restent « Non joué » —
/// assez pour voir les deux états dans le même golden.
class _FixedLevelsRepository implements SessionRepository {
  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(String playerId) async => {
    ExerciseType.addition: LevelCacheEntry(
      level: 42,
      sessionsPlayed: 5,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    ExerciseType.multiplication: LevelCacheEntry(
      level: 7,
      sessionsPlayed: 1,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  };

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw UnimplementedError();

  @override
  Future<List<PersistedSession>> recentSessions({int limit = 20}) => throw UnimplementedError();

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) => throw UnimplementedError();

  @override
  Future<Map<ExerciseType, double>> averageElapsedMsByType(String playerId) =>
      throw UnimplementedError();

  @override
  Future<List<PersistedSession>> sessionsSince(String playerId, DateTime since) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('écran de progression — ${mode.name}', (tester) async {
      await setGoldenSurfaceSize(tester);
      final environment = AppEnvironment(
        repository: _FixedLevelsRepository(),
        playerId: 'golden-player',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.theme,
          home: Scaffold(body: ProgressScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProgressScreen),
        matchesGoldenFile('goldens/progress_screen_${mode.name}.png'),
      );
    });
  }
}
