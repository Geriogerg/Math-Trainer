import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/domain/models/exercise_type.dart';
import 'package:math_trainer/core/domain/persistence/level_cache_entry.dart';
import 'package:math_trainer/core/domain/persistence/persisted_answer.dart';
import 'package:math_trainer/core/domain/persistence/persisted_session.dart';
import 'package:math_trainer/core/domain/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'golden_test_utils.dart';

/// Niveaux fixes pour deux types, les cinq autres restent « Non joué » —
/// assez pour voir les deux états dans le même golden. Dates de session
/// relatives à `DateTime.now()` (calculées une fois à la construction) :
/// l'écran positionne la courbe par rapport à « maintenant », des dates
/// figées en dur dériveraient hors de la fenêtre de 30 jours au fil du
/// temps et rendraient le golden non reproductible.
class _FixedLevelsRepository implements SessionRepository {
  _FixedLevelsRepository(DateTime now)
    : _windowSessions = [
        _session(
          'window-1',
          now.subtract(const Duration(days: 25)),
          level: 20,
          score: 40,
        ),
        _session(
          'window-2',
          now.subtract(const Duration(days: 15)),
          level: 30,
          score: 60,
        ),
        _session(
          'window-3',
          now.subtract(const Duration(days: 5)),
          level: 42,
          score: 90,
        ),
      ],
      _recentSessions = [
        _session(
          'recent-1',
          now.subtract(const Duration(days: 5)),
          level: 42,
          score: 90,
        ),
        _session(
          'recent-2',
          now.subtract(const Duration(days: 15)),
          level: 30,
          score: 60,
        ),
        _session(
          'recent-3',
          now.subtract(const Duration(days: 25)),
          level: 20,
          score: 40,
        ),
      ];

  final List<PersistedSession> _windowSessions;
  final List<PersistedSession> _recentSessions;

  static PersistedSession _session(
    String id,
    DateTime createdAt, {
    required int level,
    required int score,
  }) => PersistedSession(
    id: id,
    playerId: 'golden-player',
    seed: 1,
    enabledTypes: const {ExerciseType.addition},
    exerciseCount: 4,
    totalScore: score,
    levels: {ExerciseType.addition: level},
    createdAt: createdAt,
  );

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async => {
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
  Future<Map<ExerciseType, double>> averageElapsedMsByType(
    String playerId,
  ) async => {ExerciseType.addition: 1200, ExerciseType.multiplication: 3400};

  @override
  Future<List<PersistedSession>> sessionsSince(
    String playerId,
    DateTime since,
  ) async => _windowSessions;

  @override
  Future<List<PersistedSession>> recentSessions(
    String playerId, {
    int limit = 20,
  }) async => _recentSessions;

  @override
  Future<void> transferPlayerData({
    required String fromPlayerId,
    required String toPlayerId,
  }) async {}

  @override
  Future<void> recordSession({
    required PersistedSession session,
    required List<PersistedAnswer> answers,
    required Map<ExerciseType, LevelCacheEntry> levelUpdates,
  }) => throw UnimplementedError();

  @override
  Future<List<PersistedAnswer>> answersForSession(String sessionId) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('écran de profil — ${mode.name}', (tester) async {
      await setGoldenSurfaceSize(tester);
      final environment = AppEnvironment(
        repository: _FixedLevelsRepository(DateTime.now().toUtc()),
        playerId: 'golden-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository()..displayName = 'Alex',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.theme,
          home: Scaffold(body: ProfileScreen(environment: environment)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(ProfileScreen),
        matchesGoldenFile('goldens/profile_screen_${mode.name}.png'),
      );
    });
  }
}
