import 'package:material_ui/material_ui.dart';

import 'package:math_core/duel/duel_mode.dart';

import '../kit/kit.dart';
import 'duel_texts.dart';

/// A mode's one line on Online (Phase 6b commit 4, review M16).
String duelModeRule(DuelMode mode) => switch (mode) {
  DuelMode.basics => '8 questions, 2 each of + − × ÷.',
  DuelMode.advanced => '8 questions, 2 each of x², √, % and ∫.',
  DuelMode.count => '3 rounds of 30 s: get closest to the target.',
};

/// The rules before a duel starts, Start or Cancel (review M15: a rated duel
/// started on one tap, with no rules and no warning): `true` to go on.
Future<bool> confirmDuel(BuildContext context, DuelMode mode) => showRules(
  context,
  title: '${duelModeLabel(mode)} duel',
  lines: [
    switch (mode) {
      DuelMode.basics =>
        '8 questions, 2 each of + − × ÷, 30 s each. More right answers '
            'wins; if tied, the faster.',
      DuelMode.advanced =>
        '8 questions, 2 each of x², √, % and ∫, 30 s each. More right '
            'answers wins; if tied, the faster.',
      DuelMode.count =>
        '3 rounds of 30 s, the same numbers for both. Closer to the targets '
            'wins; if tied, the faster.',
    },
    'Rated: both ratings move — unless no player is found and you race a '
        'practice opponent.',
    'Leaving counts as a loss.',
  ],
);
