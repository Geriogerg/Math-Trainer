import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/main_level.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/persistence/level_cache_entry.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:test/test.dart';

LevelCacheEntry _level(int hundredths) => LevelCacheEntry(
  level: Level.fromHundredths(hundredths),
  sessionsPlayed: 1,
  updatedAt: DateTime.utc(2026, 11, 17),
);

PersistedSession _session(
  String id,
  int day,
  Map<ExerciseType, int> frozen, {
  SessionKind kind = SessionKind.game,
}) => PersistedSession(
  id: id,
  playerId: 'p',
  seed: 1,
  enabledTypes: frozen.keys.toSet(),
  exerciseCount: 4,
  totalScore: 0,
  levels: {
    for (final MapEntry(:key, :value) in frozen.entries)
      key: Level.fromHundredths(value),
  },
  createdAt: DateTime.utc(2026, 11, day),
  kind: kind,
);

void main() {
  group('families', () {
    test('basics are the four arithmetic operations, in index order', () {
      expect(ExerciseFamily.basics.types, [
        ExerciseType.addition,
        ExerciseType.subtraction,
        ExerciseType.multiplication,
        ExerciseType.division,
      ]);
    });

    test('every type is in exactly one family', () {
      expect(
        [...ExerciseFamily.basics.types, ...ExerciseFamily.advanced.types]
          ..sort((a, b) => a.index - b.index),
        ExerciseType.values,
      );
    });
  });

  group('mainLevel', () {
    test('no type played: floor level 1', () {
      expect(mainLevel(const {}), 1);
    });

    test('a basic never played counts at the floor', () {
      // (43 + 3 × 1) / 4.
      expect(mainLevel({ExerciseType.addition: _level(4300)}), 11.5);
    });

    test('advanced operations never count', () {
      expect(
        mainLevel({
          for (final type in ExerciseFamily.basics.types) type: _level(2000),
          for (final type in ExerciseFamily.advanced.types) type: _level(9000),
        }),
        20,
      );
    });

    test('continuous: hundredths reach the mean, in level units', () {
      expect(
        mainLevel({ExerciseType.addition: _level(3742)}),
        closeTo((37.42 + 3) / 4, 1e-12),
      );
    });
  });

  group('mainLevelsAfter', () {
    test('walks back: a completed game restores its frozen levels', () {
      final first = _session('a', 1, {ExerciseType.addition: 1000});
      final second = _session('b', 2, {ExerciseType.addition: 1200});
      final after = mainLevelsAfter(
        sessions: [
          (session: second, completed: true),
          (session: first, completed: true),
        ],
        current: {ExerciseType.addition: Level.fromHundredths(1400)},
      );
      expect(after['b'], (14 + 3) / 4);
      expect(after['a'], (12 + 3) / 4);
    });

    test('an interrupted session moved nothing', () {
      final first = _session('a', 1, {ExerciseType.addition: 1000});
      final interrupted = _session('b', 2, {ExerciseType.addition: 1000});
      final after = mainLevelsAfter(
        sessions: [
          (session: first, completed: true),
          (session: interrupted, completed: false),
        ],
        current: {ExerciseType.addition: Level.fromHundredths(1100)},
      );
      expect(after['b'], (11 + 3) / 4);
      expect(after['a'], (11 + 3) / 4);
    });

    test('undoing a placement removes the levels it created', () {
      final placement = _session('p', 1, {
        for (final type in ExerciseFamily.basics.types) type: 2000,
      }, kind: SessionKind.placementV2);
      final game = _session('g', 2, {ExerciseType.addition: 3000});
      final after = mainLevelsAfter(
        sessions: [
          (session: placement, completed: true),
          (session: game, completed: true),
        ],
        current: {
          ExerciseType.addition: Level.fromHundredths(3200),
          ExerciseType.subtraction: Level.fromHundredths(2500),
          ExerciseType.multiplication: Level.fromHundredths(2500),
          ExerciseType.division: Level.fromHundredths(2500),
        },
      );
      expect(after['g'], (32 + 25 * 3) / 4);
      expect(after['p'], (30 + 25 * 3) / 4);
    });

    test('advanced games change no main level', () {
      final power = _session('w', 1, {ExerciseType.power: 1000});
      final after = mainLevelsAfter(
        sessions: [(session: power, completed: true)],
        current: {ExerciseType.power: Level.fromHundredths(5000)},
      );
      expect(after['w'], 1);
    });
  });
}
