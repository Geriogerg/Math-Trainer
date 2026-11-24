import 'dart:math';

import 'package:math_core/generation/game_generator.dart';
import 'package:math_core/generation/question_plan.dart';
import 'package:math_core/leveling/level.dart';
import 'package:math_core/leveling/rules_version.dart';
import 'package:math_core/models/exercise.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/session_kind.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/persistence/exercise_codec.dart';
import 'package:math_core/persistence/persisted_answer.dart';
import 'package:math_core/persistence/persisted_session.dart';
import 'package:math_core/replay/session_replay.dart';
import 'package:math_core/sync/session_upload.dart';
import 'package:math_core/tiers/tier.dart';
import 'package:math_core/tiers/tiered_game_generator.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/levelling.dart';
import 'package:test/test.dart';

const _mul = ExerciseType.multiplication;
const _add = ExerciseType.addition;

List<Exercise> _game(
  RulesVersion rules, {
  required int seed,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> sequence,
  List<Item> weakSpots = const [],
}) {
  final generator = gameExerciseGenerator(
    rulesVersion: rules,
    enabledTypes: levels.keys.toSet(),
    levels: levels,
    typeSequence: sequence,
    weakSpots: weakSpots,
  );
  final random = Random(seed);
  return [for (var i = 0; i < sequence.length; i++) generator.next(random)];
}

PersistedSession _session({
  required Map<ExerciseType, Level> levels,
  required int seed,
  List<Item> weakSpots = const [],
  RulesVersion rules = RulesVersion.v7,
  SessionKind kind = SessionKind.game,
}) {
  final sequence = shuffledTypeSequence(
    types: levels.keys.toSet(),
    perOperation: 10,
    seed: seed,
  );
  return PersistedSession(
    id: 's$seed',
    playerId: 'p',
    seed: seed,
    enabledTypes: levels.keys.toSet(),
    exerciseCount: sequence.length,
    totalScore: 0,
    levels: levels,
    createdAt: DateTime.utc(2026, 11, 25),
    kind: kind,
    typeSequence: sequence,
    rulesVersion: rules,
    weakSpots: weakSpots,
  );
}

void main() {
  final sevenEight = Item.parse('fact:multiplication:7,8');
  final sixNine = Item.parse('fact:multiplication:6,9');
  final bond = Item.parse('fact:addition:7,8');

  test('rules v7 is replayed; v8 draws the same questions', () {
    expect(RulesVersion.replayed, contains(RulesVersion.v7));
    final levels = {_mul: Level.whole(15), _add: Level.whole(12)};
    final sequence = shuffledTypeSequence(
      types: levels.keys.toSet(),
      perOperation: 10,
      seed: 5,
    );
    for (final weak in [
      <Item>[],
      [sevenEight, bond],
    ]) {
      expect(
        _game(
          RulesVersion.v8,
          seed: 5,
          levels: levels,
          sequence: sequence,
          weakSpots: weak,
        ),
        _game(
          RulesVersion.v7,
          seed: 5,
          levels: levels,
          sequence: sequence,
          weakSpots: weak,
        ),
      );
    }
  });

  test('a v7 game without weak spots is a v6 game, question for question', () {
    for (var seed = 0; seed < 200; seed++) {
      final levels = {
        for (final type in ExerciseType.values)
          type: Level.fromHundredths((seed * 397 + type.index * 1231) % 10001),
      };
      final sequence = shuffledTypeSequence(
        types: levels.keys.toSet(),
        perOperation: 5,
        seed: seed,
      );
      expect(
        _game(RulesVersion.v7, seed: seed, levels: levels, sequence: sequence),
        _game(RulesVersion.v6, seed: seed, levels: levels, sequence: sequence),
      );
    }
  });

  test('each weak spot is asked once, from the current tier, in a form the '
      'tier draws', () {
    final levels = {_mul: Level.whole(15), _add: Level.whole(12)};
    for (var seed = 0; seed < 500; seed++) {
      final sequence = shuffledTypeSequence(
        types: levels.keys.toSet(),
        perOperation: 10,
        seed: seed,
      );
      final items = [sevenEight, sixNine, bond];
      expect(weakSpotProblem(items, sequence, levels), isNull);
      final generator =
          gameExerciseGenerator(
                rulesVersion: RulesVersion.v7,
                enabledTypes: levels.keys.toSet(),
                levels: levels,
                typeSequence: sequence,
                weakSpots: items,
              )
              as TieredGameGenerator;
      final random = Random(seed);
      final asked = <Item>[];
      for (var i = 0; i < sequence.length; i++) {
        final q = generator.next(random);
        expect(q.type, sequence[i]);
        if (generator.lastWeakSpot case final item?) {
          asked.add(item);
          expect(factOf(q), item);
          expect(formsAt(item as FactItem, Tier.t1), contains(q));
        }
      }
      // Each operation's items in their order.
      expect(asked.where((i) => i.type == _mul), [sevenEight, sixNine]);
      expect(asked.where((i) => i.type == _add), [bond]);
    }
  });

  test('a skill is a new question of its family at the tier\'s size', () {
    const skill = SkillItem(PatternFamily.differenceOfSquares);
    final levels = {_mul: Level.whole(55)};
    final sequence = List.filled(10, _mul);
    final generator =
        gameExerciseGenerator(
              rulesVersion: RulesVersion.v7,
              enabledTypes: {_mul},
              levels: levels,
              typeSequence: sequence,
              weakSpots: [skill],
            )
            as TieredGameGenerator;
    final random = Random(9);
    var seen = 0;
    for (var i = 0; i < 10; i++) {
      generator.next(random);
      if (generator.lastWeakSpot != null) {
        seen++;
        expect(generator.lastFamily, PatternFamily.differenceOfSquares);
      }
    }
    expect(seen, 1);
  });

  test('weak spots break no rule: other versions, lower tiers, caps throw', () {
    final levels = {_mul: Level.whole(25)};
    final sequence = List.filled(10, _mul);
    for (final (rules, items) in [
      (RulesVersion.v6, [Item.parse('fact:multiplication:7,12')]),
      (RulesVersion.v7, [sevenEight]), // T1 content at T2
    ]) {
      expect(
        () => gameExerciseGenerator(
          rulesVersion: rules,
          enabledTypes: {_mul},
          levels: levels,
          typeSequence: sequence,
          weakSpots: items,
        ),
        throwsArgumentError,
      );
    }
  });

  group('stored with the session, replayed by the server alone', () {
    final levels = {_mul: Level.whole(15)};

    PersistedAnswer answer(PersistedSession s, int i, Exercise q) {
      final d = describeExerciseForStorage(q);
      return PersistedAnswer(
        id: '${s.id}-$i',
        sessionId: s.id,
        exerciseType: d.exerciseType,
        operationType: d.operationType,
        operands: d.operands,
        submittedValue: q.correctAnswer,
        isCorrect: true,
        elapsedMs: 2000,
        createdAt: s.createdAt,
      );
    }

    SessionUpload upload(PersistedSession s) {
      final questions = _game(
        RulesVersion.v7,
        seed: s.seed,
        levels: s.levels,
        sequence: s.typeSequence!,
        weakSpots: s.weakSpots,
      );
      return SessionUpload(
        session: s,
        answers: [for (final (i, q) in questions.indexed) answer(s, i, q)],
      );
    }

    test('the upload carries the keys; the replay asks the same questions; '
        'the server accepts', () {
      final s = _session(levels: levels, seed: 3, weakSpots: [sevenEight]);
      final json = upload(s).toJson();
      expect((json['session']! as Map)['weakSpots'], [
        'fact:multiplication:7,8',
      ]);
      final back = SessionUpload.fromJson(json);
      expect(back.session, s);
      expect(
        replaySessionQuestions(back.session, 10),
        _game(
          RulesVersion.v7,
          seed: 3,
          levels: levels,
          sequence: s.typeSequence!,
          weakSpots: [sevenEight],
        ),
      );
      final verdict = validateSessionUpload(
        upload: back,
        callerId: 'p',
        state: ServerPlayerState(),
        receivedAt: DateTime.utc(2026, 11, 26),
      );
      // Level 15 is not the server's 0: the chain refuses it, after the
      // replay accepted every question.
      expect((verdict as Rejected).reason, RejectionReason.levelsMismatch);
    });

    test('without weak spots, no field: older sessions keep their shape', () {
      final json = upload(_session(levels: levels, seed: 4)).toJson();
      expect((json['session']! as Map).containsKey('weakSpots'), isFalse);
    });

    test('a lower tier\'s item, a training game, v6: not replayable', () {
      for (final s in [
        _session(
          levels: {_mul: Level.whole(25)},
          seed: 5,
          weakSpots: [sevenEight],
        ),
        _session(
          levels: levels,
          seed: 6,
          weakSpots: [sevenEight],
          kind: SessionKind.training,
        ),
        _session(
          levels: levels,
          seed: 7,
          weakSpots: [sevenEight],
          rules: RulesVersion.v6,
        ),
      ]) {
        expect(
          () => replaySessionQuestions(s, 10),
          throwsA(isA<SessionNotReplayable>()),
        );
      }
    });

    test('a key that is no item is a bad upload', () {
      final json = upload(_session(levels: levels, seed: 8)).toJson();
      (json['session']! as Map)['weakSpots'] = ['fact:multiplication:8,7'];
      expect(() => SessionUpload.fromJson(json), throwsFormatException);
    });
  });

  test('determinism: a v7 game with weak spots, the same on VM and '
      'JavaScript', () {
    final levels = {_mul: Level.whole(15), _add: Level.whole(12)};
    final sequence = shuffledTypeSequence(
      types: levels.keys.toSet(),
      perOperation: 10,
      seed: 2026,
    );
    final questions = _game(
      RulesVersion.v7,
      seed: 2026,
      levels: levels,
      sequence: sequence,
      weakSpots: [sevenEight, sixNine, bond],
    );
    expect(
      [
        for (final q in questions)
          describeExerciseForStorage(q).operands.values.join(' '),
      ].join(', '),
      _pinned,
    );
  });
}

// Recorded on the VM (Phase 4 commit 3); JavaScript must match it.
const _pinned =
    '7 8, 7 4, 3 9, 8 7, 7 7, 96 6, 10 2, 30 30, 4 9, 9 10, 29 29, 5 8, '
    '60 61, 6 7, 2 9, 8 6, 61 9, 9 6, 40 41, 58 58';
