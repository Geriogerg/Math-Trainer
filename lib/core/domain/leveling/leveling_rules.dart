/// Paramètres de la formule de mise à jour du niveau. Valeurs non calibrées
/// (issues d'un simulateur, pas de données réelles) — voir `doc/decisions.md`
/// pour la sémantique de chacune et les cibles de réglage.
class LevelingRules {
  LevelingRules({
    this.pCible = 0.70,
    this.f = 0.30,
    this.kHaut = 3.0,
    this.kBas = 1.5,
    this.delta = 0.05,
    this.deltaMax = 3,
    this.nMin = 8,
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
        'doit être strictement supérieur à tRapideMs ($tRapideMs).',
      );
    }
    if (absenceDaysThreshold <= 0) {
      throw ArgumentError.value(
        absenceDaysThreshold,
        'absenceDaysThreshold',
        'doit être strictement positif.',
      );
    }
    if (nMin <= 0) {
      throw ArgumentError.value(nMin, 'nMin', 'doit être strictement positif.');
    }
  }

  /// Performance d'équilibre visée.
  final double pCible;

  /// Crédit d'une bonne réponse lente ; paramètre de tempérament.
  final double f;

  /// Vitesse de montée du niveau.
  final double kHaut;

  /// Vitesse de descente du niveau ; ratio kHaut/kBas volontairement 2:1.
  final double kBas;

  /// Bande morte : en deçà, le niveau ne bouge pas.
  final double delta;

  /// Déplacement maximal du niveau par session.
  final int deltaMax;

  /// En deçà de ce nombre de réponses, la session ne compte pas (bruit).
  final int nMin;

  /// Multiplicateur de confiance pendant les 3 premières sessions d'une opération.
  final double kCalib;

  /// Multiplicateur de confiance après une longue absence.
  final double boostRetour;

  /// Sous ce temps de réponse (ms), vitesse = 1.
  final int tRapideMs;

  /// Au-dessus de ce temps de réponse (ms), vitesse = 0.
  final int tLentMs;

  /// Nombre de jours sans réponse sur une opération au-delà duquel
  /// `confidenceFor` bascule sur `returning`.
  final int absenceDaysThreshold;
}

/// `calibration` = `kCalib` (3 premières sessions d'une opération),
/// `returning` = `boostRetour` (après une longue absence). Le décompte des
/// sessions et de l'absence n'appartient pas à ce module : l'appelant décide
/// quelle valeur passer, à partir de l'historique qu'il a sous la main.
enum ConfidenceMultiplier { normal, calibration, returning }
