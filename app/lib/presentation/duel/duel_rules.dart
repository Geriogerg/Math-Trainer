import 'package:material_ui/material_ui.dart';
import '../strings/strings.dart';

import 'package:math_core/duel/duel_mode.dart';

import '../../core/state/hints.dart';
import '../kit/kit.dart';
import 'package:math_trainer/presentation/strings/duel_texts.dart';

/// A mode's one line on Online (Phase 6b commit 4, review M16).
String duelModeRule(DuelMode mode) => strings.online.modeRule(mode);

/// The rules before a rated duel, Start or Cancel (review M15: a rated duel
/// started on one tap, with no rules and no warning): `true` to go on.
///
/// Once per mode (plan v4.1, "Phase 6b outcome": every time was friction for
/// a returning player): shown before the first rated duel of [mode] on this
/// device, remembered on Start; afterwards the reminder line
/// ([DuelReminder]) says it and the full rules are one tap away. Without a
/// store ([hints] `null`) the sheet shows every time.
Future<bool> confirmDuel(
  BuildContext context,
  DuelMode mode, {
  required HintsStore? hints,
}) async {
  final hint = duelRulesHint(mode);
  if (hints != null && await hints.seen(hint)) return true;
  if (!context.mounted) return false;
  final go = await showRules(
    context,
    title: strings.online.rulesTitle(duelModeLabel(mode)),
    lines: strings.online.rules(mode),
  );
  if (go) await hints?.markSeen(hint);
  return go;
}

/// Every mode's rules, read only (the reminder's link).
Future<void> showDuelRules(BuildContext context) => showRules(
  context,
  title: strings.online.allRulesTitle,
  lines: strings.online.allRules,
  cancellable: false,
);

/// "Rated · leaving counts as a loss" and a link to the full rules (plan
/// v4.1): where a duel is chosen — Online's duel list and a friend
/// challenge's mode picker.
class DuelReminder extends StatelessWidget {
  const DuelReminder({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Caption(strings.online.ratedReminder)),
      AppButton.secondary(
        label: strings.online.rulesLink,
        semanticLabel: strings.online.rulesLinkSpoken,
        onPressed: () => showDuelRules(context),
      ),
    ],
  );
}
