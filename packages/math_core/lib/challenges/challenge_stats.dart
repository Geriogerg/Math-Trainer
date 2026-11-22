/// The two solo challenges (Redesign phase). Their names are stored (the
/// device's stats).
enum Challenge { getTheCount, chainOperations }

/// A challenge's personal record, kept on the device only (plan v2.9: no
/// level, not ranked, not uploaded for now).
final class ChallengeStats {
  const ChallengeStats({this.games = 0, this.solved = 0, this.bestTimeMs});

  static const none = ChallengeStats();

  final int games;
  final int solved;

  /// The fastest solved round; `null` until one is solved.
  final int? bestTimeMs;

  /// One more round: solved in [elapsedMs], or not.
  ChallengeStats record({required bool solved, required int elapsedMs}) {
    if (elapsedMs < 0) {
      throw ArgumentError.value(
        elapsedMs,
        'elapsedMs',
        'must not be negative.',
      );
    }
    final best = bestTimeMs;
    return ChallengeStats(
      games: games + 1,
      solved: this.solved + (solved ? 1 : 0),
      bestTimeMs: solved && (best == null || elapsedMs < best)
          ? elapsedMs
          : best,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChallengeStats &&
      other.games == games &&
      other.solved == solved &&
      other.bestTimeMs == bestTimeMs;

  @override
  int get hashCode => Object.hash(games, solved, bestTimeMs);
}

/// On the device (rule 3: the concrete store lives in the app's
/// `infrastructure/`).
abstract class ChallengeStatsStore {
  Future<ChallengeStats> load(Challenge challenge);

  Future<void> save(Challenge challenge, ChallengeStats stats);
}
