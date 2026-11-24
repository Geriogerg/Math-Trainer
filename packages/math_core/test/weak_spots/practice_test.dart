import 'dart:math';

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
import 'package:math_core/validation/session_validation.dart';
import 'package:math_core/weak_spots/facts.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/practice.dart';
import 'package:test/test.dart';

const _mul = ExerciseType.multiplication;
const _add = ExerciseType.addition;

PersistedSession _practice({
  required SessionKind kind,
  required List<Item> items,
  required Map<ExerciseType, Level> levels,
  required List<ExerciseType> sequence,
  int seed = 11,
  RulesVersion rules = RulesVersion.v7,
}) => PersistedSession(
  id: '${kind.name}$seed',
  playerId: 'p',
  seed: seed,
  enabledTypes: sequence.toSet(),
  exerciseCount: sequence.length,
  totalScore: 0,
  levels: levels,
  createdAt: DateTime.utc(2026, 11, 25),
  kind: kind,
  typeSequence: sequence,
  rulesVersion: rules,
  weakSpots: items,
);

SessionUpload _played(PersistedSession s) {
  final questions = replaySessionQuestions(s, s.exerciseCount);
  return SessionUpload(
    session: s,
    answers: [
      for (final (i, q) in questions.indexed)
        () {
          final d = describeExerciseForStorage(q);
          return PersistedAnswer(
            id: '${s.id}-$i',
            sessionId: s.id,
            exerciseType: d.exerciseType,
            operationType: d.operationType,
            operands: d.operands,
            submittedValue: q.correctAnswer,
            isCorrect: true,
            elapsedMs: 1500,
            createdAt: s.createdAt,
          );
        }(),
    ],
  );
}

void main() {
  final sevenEight = Item.parse('fact:multiplication:7,8');
  final twelveSeven = Item.parse('fact:multiplication:7,12');
  final bond = Item.parse('fact:addition:7,8');
  const squares = SkillItem(PatternFamily.differenceOfSquares);

  group('Weak spots game: any tier up to the player\'s own', () {
    test('practisable: a fact at or below the tier, a family started', () {
      expect(practisable(sevenEight, Level.whole(15)), isTrue);
      expect(practisable(sevenEight, Level.whole(85)), isTrue);
      expect(practisable(sevenEight, Level.whole(5)), isFalse);
      expect(practisable(twelveSeven, Level.whole(15)), isFalse);
      expect(practisable(squares, Level.whole(49)), isFalse);
      expect(practisable(squares, Level.whole(50)), isTrue);
    });

    test('the due items it may ask, most urgent first, at most 10', () {
      final many = {
        for (final q in factsAt(_mul, Tier.t1)) factOf(q)!,
      }.toList();
      expect(
        chooseWeakSpotsGame(
          due: [twelveSeven, squares, sevenEight, bond],
          levels: {_mul: Level.whole(15), _add: Level.whole(3)},
        ),
        [sevenEight],
      );
      expect(
        chooseWeakSpotsGame(due: many, levels: {_mul: Level.whole(15)}),
        many.take(weakSpotsGameLength),
      );
    });

    test('each item in turn: a fact in a form of its home tier, a skill at '
        'the player\'s tier', () {
      final levels = {_mul: Level.whole(65), _add: Level.whole(40)};
      final items = [sevenEight, squares, bond, twelveSeven];
      for (var seed = 0; seed < 200; seed++) {
        final g = WeakSpotsGameGenerator(items: items, levels: levels);
        final random = Random(seed);
        final asked = [for (var i = 0; i < 4; i++) g.next(random)];
        expect(formsAt(sevenEight as FactItem, Tier.t1), contains(asked[0]));
        expect(factOf(asked[1]), isNull);
        expect(formsAt(bond as FactItem, homeTier(bond)!), contains(asked[2]));
        expect(formsAt(twelveSeven as FactItem, Tier.t2), contains(asked[3]));
      }
    });

    test('stored, replayed, accepted by the server, no level moved', () {
      final s = _practice(
        kind: SessionKind.weakSpots,
        items: [sevenEight, bond],
        levels: {_mul: Level.whole(15), _add: Level.whole(12)},
        sequence: const [_mul, _add],
      );
      final upload = SessionUpload.fromJson(_played(s).toJson());
      expect(upload.session, s);
      final verdict = validateSessionUpload(
        upload: upload,
        callerId: 'p',
        state: ServerPlayerState.empty,
        receivedAt: DateTime.utc(2026, 11, 26),
      );
      expect(verdict, isA<Accepted>());
      expect((verdict as Accepted).levelUpdates, isEmpty);
      expect(verdict.completed, isTrue);
    });

    test('above the player\'s tier, a sequence that is not the items, '
        'empty: not replayable', () {
      for (final s in [
        _practice(
          kind: SessionKind.weakSpots,
          items: [twelveSeven],
          levels: {_mul: Level.whole(15)},
          sequence: const [_mul],
        ),
        _practice(
          kind: SessionKind.weakSpots,
          items: [sevenEight],
          levels: {_mul: Level.whole(15), _add: Level.whole(5)},
          sequence: const [_add],
        ),
        _practice(
          kind: SessionKind.weakSpots,
          items: const [],
          levels: {_mul: Level.whole(15)},
          sequence: const [_mul],
        ),
        _practice(
          kind: SessionKind.weakSpots,
          items: [sevenEight],
          levels: {_mul: Level.whole(15)},
          sequence: const [_mul],
          rules: RulesVersion.v6,
        ),
      ]) {
        expect(
          () => replaySessionQuestions(s, s.exerciseCount),
          throwsA(isA<SessionNotReplayable>()),
        );
      }
    });
  });

  group('Drill: one tip\'s strategy, 10 questions', () {
    test('the tier: the player\'s, or the families\' lowest start; '
        'without families, the player\'s brought into the band', () {
      expect(
        drillTier(
          families: [PatternFamily.differenceOfSquares],
          playerTier: Tier.t2,
          bandLow: Tier.t6,
          bandHigh: Tier.t9,
        ),
        Tier.t5,
      );
      expect(
        drillTier(
          families: [PatternFamily.differenceOfSquares],
          playerTier: Tier.t7,
          bandLow: Tier.t6,
          bandHigh: Tier.t9,
        ),
        Tier.t7,
      );
      expect(
        drillTier(
          families: const [],
          playerTier: Tier.t6,
          bandLow: Tier.t0,
          bandHigh: Tier.t2,
        ),
        Tier.t2,
      );
      expect(
        drillTier(
          families: const [],
          playerTier: Tier.t1,
          bandLow: Tier.t3,
          bandHigh: Tier.t5,
        ),
        Tier.t3,
      );
    });

    test('a family available at the tier each time, or standard questions', () {
      final g = DrillGenerator(
        type: _mul,
        tier: Tier.t5,
        families: const [
          PatternFamily.differenceOfSquares,
          PatternFamily.differenceOfSquaresHundreds, // T9: not yet
        ],
      );
      final random = Random(1);
      for (var i = 0; i < 50; i++) {
        g.next(random);
        expect(g.lastFamily, PatternFamily.differenceOfSquares);
      }
      final plain = DrillGenerator(
        type: _add,
        tier: Tier.t1,
        families: const [],
      );
      expect(plain.next(random).type, _add);
      expect(plain.lastFamily, isNull);
    });

    test('stored, replayed, accepted, no level moved; a family of another '
        'operation refused', () {
      final s = _practice(
        kind: SessionKind.drill,
        items: [squares],
        levels: {_mul: Level.whole(50)},
        sequence: List.filled(drillGameLength, _mul),
      );
      final verdict = validateSessionUpload(
        upload: SessionUpload.fromJson(_played(s).toJson()),
        callerId: 'p',
        state: ServerPlayerState.empty,
        receivedAt: DateTime.utc(2026, 11, 26),
      );
      expect((verdict as Accepted).levelUpdates, isEmpty);
      expect(replaySessionPatterns(s, 10).toSet(), {
        PatternFamily.differenceOfSquares,
      });
      final wrong = _practice(
        kind: SessionKind.drill,
        items: [const SkillItem(PatternFamily.doubles)],
        levels: {_mul: Level.whole(50)},
        sequence: List.filled(drillGameLength, _mul),
      );
      expect(
        () => replaySessionQuestions(wrong, 10),
        throwsA(isA<SessionNotReplayable>()),
      );
    });
  });

  test('the kinds a server accepts: every kind but the placements; without '
      'a list, games and Training', () {
    expect(SessionKind.acceptedByServer, [
      for (final k in SessionKind.values)
        if (!k.isPlacement) k,
    ]);
    expect(SessionKind.acceptedWithoutList, [
      SessionKind.game,
      SessionKind.training,
    ]);
  });

  test('practice kinds never move levels and are not placements', () {
    for (final kind in [SessionKind.weakSpots, SessionKind.drill]) {
      expect(kind.movesLevels, isFalse);
      expect(kind.isPractice, isTrue);
      expect(kind.isPlacement, isFalse);
    }
    expect(SessionKind.game.movesLevels, isTrue);
    expect(SessionKind.training.isPractice, isFalse);
  });

  test('a practice game replays deterministically from its seed', () {
    final s = _practice(
      kind: SessionKind.weakSpots,
      items: [sevenEight, squares],
      levels: {_mul: Level.whole(55)},
      sequence: const [_mul, _mul],
      seed: 77,
    );
    final a = replaySessionQuestions(s, 2);
    final b = replaySessionQuestions(s, 2);
    expect(a, b);
    expect(a.first, isA<ArithmeticExercise>());
  });
}
