import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import 'package:math_core/duel/duel_mode.dart';

import '../kit/kit.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';

/// A mode's one line on Online (Phase 6b commit 4, review M16).
String duelModeRule(DuelMode mode) => strings.online.modeRule(mode);

/// The rules before a duel starts, Start or Cancel (review M15: a rated duel
/// started on one tap, with no rules and no warning): `true` to go on.
Future<bool> confirmDuel(BuildContext context, DuelMode mode) => showRules(
  context,
  title: strings.online.rulesTitle(duelModeLabel(mode)),
  lines: strings.online.rules(mode),
);
