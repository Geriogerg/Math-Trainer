import 'package:math_core/persistence/session_repository.dart';
import 'package:math_core/weak_spots/history.dart';
import 'package:math_core/weak_spots/item.dart';
import 'package:math_core/weak_spots/scheduler.dart';

/// Answers to a group of items: how many, how many right, their times.
final class AnswerStats {
  int answers = 0;
  int right = 0;
  final rightMs = <int>[];

  void add(ItemAnswer a) {
    answers++;
    if (a.isCorrect) {
      right++;
      rightMs.add(a.elapsedMs);
    }
  }

  /// Percent right; `null` without answers.
  double? get rightPercent => answers == 0 ? null : 100 * right / answers;

  /// Median time of the right answers; `null` without any.
  int? get medianRightMs {
    if (rightMs.isEmpty) return null;
    final sorted = [...rightMs]..sort();
    return sorted[sorted.length ~/ 2];
  }
}

/// One player's answers to tracked items (Phase 4 commit 7): items that
/// entered the schedule, answers up to and including the miss that
/// scheduled them first ([before]) and after it ([after]); items never
/// scheduled ([never]) for comparison.
final class PlayerWeakSpots {
  PlayerWeakSpots(this.playerId);

  final String playerId;
  int games = 0;
  final scheduled = <Item>{};
  final before = AnswerStats();
  final after = AnswerStats();
  final never = AnswerStats();

  /// Of the scheduled items, how many are out of box 1 now, and mastered.
  int outOfBoxOne = 0;
  int mastered = 0;
}

/// Every player's report from their stored games, each list in time order
/// — what the scheduler replays (`scheduleFromHistory`'s path, so the
/// report reads the very items and grades the app schedules).
List<PlayerWeakSpots> weakSpotsReport(
  Map<String, List<StoredGame>> gamesByPlayer,
) {
  final reports = <PlayerWeakSpots>[];
  for (final MapEntry(key: player, value: games) in gamesByPlayer.entries) {
    final report = PlayerWeakSpots(player);
    final perGame = [for (final g in games) itemAnswersOf(g)];
    // First pass: which items ever entered the schedule — a miss, or
    // from rules v8 a slow fact.
    final enteredAt = <Item, (int, int)>{}; // game, answer index
    for (final (g, answers) in perGame.indexed) {
      final slowEnters = games[g].session.rulesVersion.slowFactsEnterSchedule;
      for (final (i, a) in answers.indexed) {
        final enters =
            a.grade == Grade.miss ||
            (slowEnters && a.grade == Grade.slow && a.item is FactItem);
        if (enters) enteredAt.putIfAbsent(a.item, () => (g, i));
      }
    }
    report.scheduled.addAll(enteredAt.keys);
    for (final (g, answers) in perGame.indexed) {
      for (final (i, a) in answers.indexed) {
        final entered = enteredAt[a.item];
        if (entered == null) {
          report.never.add(a);
        } else if (g < entered.$1 || (g == entered.$1 && i <= entered.$2)) {
          report.before.add(a);
        } else {
          report.after.add(a);
        }
      }
    }
    report.games = games.length;
    var schedule = WeakSpotSchedule.empty;
    for (final (g, answers) in perGame.indexed) {
      schedule = schedule.afterGame([
        for (final a in answers) (item: a.item, grade: a.grade),
      ], slowFactsEnter: games[g].session.rulesVersion.slowFactsEnterSchedule);
    }
    for (final item in report.scheduled) {
      final state = schedule.stateOf(item);
      if (state == null) {
        report.mastered++;
        report.outOfBoxOne++;
      } else if (state.box > 1) {
        report.outOfBoxOne++;
      }
    }
    reports.add(report);
  }
  reports.sort((a, b) => a.playerId.compareTo(b.playerId));
  return reports;
}

/// The report as text: one line per player, then everyone.
String formatWeakSpotsReport(List<PlayerWeakSpots> reports) {
  String pct(AnswerStats s) => switch (s.rightPercent) {
    null => '   —',
    final p => '${p.round()}%'.padLeft(4),
  };
  String ms(AnswerStats s) => switch (s.medianRightMs) {
    null => '     —',
    final m => '${(m / 1000).toStringAsFixed(1)} s'.padLeft(6),
  };
  String line(
    String who,
    int games,
    int items,
    int out,
    int mastered,
    AnswerStats b,
    AnswerStats a,
    AnswerStats n,
  ) =>
      '${who.padRight(10)}${'$games'.padLeft(6)}${'$items'.padLeft(7)}'
      '${'$out'.padLeft(6)}${'$mastered'.padLeft(5)}   '
      '${pct(b)} ${ms(b)} (${b.answers})   ${pct(a)} ${ms(a)} (${a.answers})'
      '   ${pct(n)} ${ms(n)} (${n.answers})';
  final buffer = StringBuffer()
    ..writeln(
      'Weak spots (Phase 4): answers to each scheduled item before and '
      'after it entered the schedule.',
    )
    ..writeln(
      '"before" includes the answer that scheduled it (a miss; from v8 also a slow fact), so it is biased '
      'low (regression to the mean):',
    )
    ..writeln('compare "after" with "never scheduled" too.')
    ..writeln()
    ..writeln(
      'player     games  items  >box1 mast   before: right, median '
      '(n)   after: right, median (n)   never scheduled',
    );
  final all = PlayerWeakSpots('all');
  var games = 0, items = 0, out = 0, mastered = 0;
  for (final r in reports) {
    buffer.writeln(
      line(
        r.playerId.substring(0, r.playerId.length.clamp(0, 8)),
        r.games,
        r.scheduled.length,
        r.outOfBoxOne,
        r.mastered,
        r.before,
        r.after,
        r.never,
      ),
    );
    games += r.games;
    items += r.scheduled.length;
    out += r.outOfBoxOne;
    mastered += r.mastered;
    for (final (from, to) in [
      (r.before, all.before),
      (r.after, all.after),
      (r.never, all.never),
    ]) {
      to.answers += from.answers;
      to.right += from.right;
      to.rightMs.addAll(from.rightMs);
    }
  }
  buffer.writeln(
    line('ALL', games, items, out, mastered, all.before, all.after, all.never),
  );
  return buffer.toString();
}
