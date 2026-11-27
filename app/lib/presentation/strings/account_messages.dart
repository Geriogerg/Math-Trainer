import 'package:math_core/account/account_exception.dart';
import 'package:math_core/account/display_name.dart';

import 'strings.dart';

/// What the player reads for an account failure — never the raw server
/// text (written for a developer), except for an unlisted failure, where it
/// is the only clue available. In the interface's language (`LabelStrings`).
String describeAccountFailure(AccountFailure failure, {String? detail}) =>
    strings.labels.accountFailure(failure, detail: detail);

/// Why a player name cannot be saved, in the player's words (Phase 2
/// commit 9: names are public content).
String describeNameProblem(DisplayNameProblem problem) =>
    strings.labels.nameProblem(problem);
