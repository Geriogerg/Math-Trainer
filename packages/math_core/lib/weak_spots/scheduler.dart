import 'item.dart';

/// How one answer to an item went, for the scheduler (plan v3.5): a wrong
/// answer or a timeout is a [miss]; a correct one is [fluent] within the
/// item's fluent time (`itemFluentMs`), [slow] beyond.
enum Grade { miss, slow, fluent }

/// One answer of a game, as the scheduler reads it.
typedef GradedAnswer = ({Item item, Grade grade});

/// Where a tracked item stands: its [box] (1 to 5) and the index of the
/// last game it was answered in.
final class ItemState {
  const ItemState(this.box, this.lastGame);

  final int box;
  final int lastGame;

  @override
  bool operator ==(Object other) =>
      other is ItemState && other.box == box && other.lastGame == lastGame;

  @override
  int get hashCode => Object.hash(box, lastGame);

  @override
  String toString() => 'box $box, game $lastGame';
}

/// Games before an item of box 1, 2, 3, 4, 5 is due again (plan v3.5).
const boxIntervals = [1, 2, 4, 8, 16];

/// The player's five boxes (plan v3.5, Phase 4), **counted in games, never
/// in days**: absence is never punished, an overdue item just stays due.
/// Immutable and pure: rebuilt from the stored answers ([WeakSpotSchedule.
/// replay]), like levels — nothing about it is stored.
///
/// `doc/decisions.md`, "Phase 4": an item enters at box 1 on its first
/// miss (a correct answer leaves an untracked item untracked); a miss sends
/// it back to box 1, a fluent answer one box up, a slow one keeps its box;
/// fluent in box 5, it is mastered and leaves the schedule until it is
/// missed again.
final class WeakSpotSchedule {
  const WeakSpotSchedule._(this._states, this.games);

  /// A player who never played.
  static const empty = WeakSpotSchedule._({}, 0);

  /// The schedule after [history], one list of answers per game, oldest
  /// first. A game without a tracked answer still counts.
  factory WeakSpotSchedule.replay(Iterable<Iterable<GradedAnswer>> history) {
    var schedule = empty;
    for (final game in history) {
      schedule = schedule.afterGame(game);
    }
    return schedule;
  }

  final Map<Item, ItemState> _states;

  /// Games played so far: the index the next game will have.
  final int games;

  /// The tracked items and where they stand.
  Map<Item, ItemState> get tracked => Map.unmodifiable(_states);

  ItemState? stateOf(Item item) => _states[item];

  /// The schedule once one more game, with [answers] in order, is played.
  WeakSpotSchedule afterGame(Iterable<GradedAnswer> answers) {
    final states = {..._states};
    for (final (:item, :grade) in answers) {
      final state = states[item];
      switch (grade) {
        case Grade.miss:
          states[item] = ItemState(1, games);
        case Grade.slow:
          if (state != null) states[item] = ItemState(state.box, games);
        case Grade.fluent:
          if (state == null) break;
          if (state.box == boxIntervals.length) {
            states.remove(item);
          } else {
            states[item] = ItemState(state.box + 1, games);
          }
      }
    }
    return WeakSpotSchedule._(Map.unmodifiable(states), games + 1);
  }

  /// Due in the next game: answered at least its box's interval of games
  /// ago.
  bool isDue(Item item) => switch (_states[item]) {
    final state? => games - state.lastGame >= boxIntervals[state.box - 1],
    null => false,
  };

  /// The items due in the next game, the most urgent first: lowest box,
  /// then most overdue, then by key (a stable order, rule 2).
  List<Item> get due {
    int overdue(Item item) {
      final state = _states[item]!;
      return games - state.lastGame - boxIntervals[state.box - 1];
    }

    final items = [
      for (final item in _states.keys)
        if (isDue(item)) item,
    ];
    items.sort((a, b) {
      final byBox = _states[a]!.box - _states[b]!.box;
      if (byBox != 0) return byBox;
      final byOverdue = overdue(b) - overdue(a);
      if (byOverdue != 0) return byOverdue;
      return a.compareTo(b);
    });
    return items;
  }
}
