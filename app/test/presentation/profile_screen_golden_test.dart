import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:math_trainer/composition_root.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/persistence/session_repository.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'golden_test_utils.dart';

/// Fixed levels for two types, the other five stay "Not played" — enough to
/// see both states in the same golden. Session dates relative to [_now],
/// which the screen also uses as its clock: the image is the same on any
/// day, at any hour, in any time zone from UTC−11 to UTC+11.
class _FixedLevelsRepository implements SessionRepository {
  @override
  Future<List<StoredGame>> storedGames(String playerId) async => const [];

  @override
  Future<List<PersistedSession>> pendingUploads(String playerId) async => [];
  @override
  Future<void> markSynced(String sessionId, DateTime syncedAt) async {}
  @override
  Future<void> markUploadRefused(String sessionId, String reason) async {}
  @override
  Future<void> replaceLevelCache(
    String playerId,
    Map<ExerciseType, LevelCacheEntry> levels,
  ) async {}
  @override
  Future<void> deletePlayerData(String playerId) => throw UnimplementedError();
  @override
  Future<bool> hasCompletedSession(String playerId) async => true;
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
    levels: {ExerciseType.addition: Level.whole(level)},
    createdAt: createdAt,
    // Same value as the entry level: keeps the curve and gaps of the
    // reference image from before `overallLevelAfter` (20 → 30 → 42).
    overallLevelAfter: level.toDouble(),
    rulesVersion: RulesVersion.current,
  );

  @override
  Future<Map<ExerciseType, LevelCacheEntry>> currentLevels(
    String playerId,
  ) async => {
    ExerciseType.addition: LevelCacheEntry(
      level: Level.whole(42),
      sessionsPlayed: 5,
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    ExerciseType.multiplication: LevelCacheEntry(
      level: Level.whole(7),
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

/// Noon UTC: the same calendar day everywhere CI and the owner run tests.
final _now = DateTime.utc(2026, 11, 20, 12);

void main() {
  setUpAll(loadInterFontForGoldens);

  for (final mode in [
    (name: 'light', theme: buildLightTheme()),
    (name: 'dark', theme: buildDarkTheme()),
  ]) {
    testWidgets('profile screen — ${mode.name}', (tester) async {
      await setGoldenSurfaceSize(tester);
      final environment = AppEnvironment(
        repository: _FixedLevelsRepository(_now),
        playerId: 'golden-player',
        accountRepository: FakeAccountRepository(),
        profileRepository: FakeProfileRepository()..displayName = 'Alex',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: mode.theme,
          home: Scaffold(
            body: ProfileScreen(environment: environment, clock: () => _now),
          ),
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
