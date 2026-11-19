/// Parameters of the level update formula. Uncalibrated values (from a
/// simulator, not real data) — see `doc/decisions.md` for the meaning of
/// each and the tuning targets.
class LevelingRules {
  LevelingRules({
    this.pCible = 0.70,
    this.f = 0.30,
    this.kHaut = 3.0,
    this.kBas = 1.5,
    this.delta = 0.07,
    this.deltaMax = 3,
    this.nMin = 4,
    this.kCalib = 4.0,
    this.boostRetour = 2.0,
    this.tRapideMs = 2000,
    this.tLentMs = 8000,
    this.absenceDaysThreshold = 30,
  }) {
    if (tRapideMs >= tLentMs) {
      throw ArgumentError.value(
        tLentMs,
        'tLentMs',
        'must be strictly greater than tRapideMs ($tRapideMs).',
      );
    }
    if (absenceDaysThreshold <= 0) {
      throw ArgumentError.value(
        absenceDaysThreshold,
        'absenceDaysThreshold',
        'must be strictly positive.',
      );
    }
    if (nMin <= 0) {
      throw ArgumentError.value(nMin, 'nMin', 'must be strictly positive.');
    }
  }

  /// Target equilibrium performance.
  final double pCible;

  /// Credit for a slow right answer; temperament parameter.
  final double f;

  /// Rising speed of the level.
  final double kHaut;

  /// Falling speed of the level; kHaut/kBas ratio 2:1 on purpose.
  final double kBas;

  /// Dead band: below it, the level does not move.
  final double delta;

  /// Maximum level move per session.
  final int deltaMax;

  /// Below this number of answers, the session does not count (noise).
  final int nMin;

  /// Confidence multiplier during an operation's first 3 sessions.
  final double kCalib;

  /// Confidence multiplier after a long absence.
  final double boostRetour;

  /// Below this response time (ms), speed = 1.
  final int tRapideMs;

  /// Above this response time (ms), speed = 0.
  final int tLentMs;

  /// Number of days without an answer on an operation beyond which
  /// `confidenceFor` switches to `returning`.
  final int absenceDaysThreshold;
}

/// `calibration` = `kCalib` (an operation's first 3 sessions),
/// `returning` = `boostRetour` (after a long absence). Counting sessions
/// and absence does not belong to this module: the caller decides which
/// value to pass, from the history it has at hand.
enum ConfidenceMultiplier { normal, calibration, returning }
