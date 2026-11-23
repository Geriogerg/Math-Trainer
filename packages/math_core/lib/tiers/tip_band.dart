import 'tier.dart';

/// The Tips page's three bands of tiers (`doc/levels.md`, section 8).
enum TipBand {
  /// T0–T2.
  beginner,

  /// T3–T5.
  intermediate,

  /// T6–T9.
  advanced;

  static TipBand of(Tier tier) => switch (tier) {
    Tier.t0 || Tier.t1 || Tier.t2 => beginner,
    Tier.t3 || Tier.t4 || Tier.t5 => intermediate,
    Tier.t6 || Tier.t7 || Tier.t8 || Tier.t9 => advanced,
  };
}
