/// Every word the app shows a player, in one place (Phase 6b commit 7,
/// review m18; plan v4.0: "strings in one place, English at launch, French
/// right after").
///
/// Screens read `strings.<area>.<name>`. Each area is a plain class whose
/// members hold the English text; a translation will be a subclass of each
/// area overriding what it translates (a member it leaves alone stays in
/// English), and [strings] will become the choice made at start from the
/// device's language. Kept as Dart, not ARB files: no context to thread
/// through, enum labels as exhaustive switches, and tests that need no
/// localisation setup.
///
/// The labels of exercise types, Method lines, tips, duels and account
/// messages live beside this file, as their own tables. A guard test
/// (`strings_in_one_place_test.dart`) fails on any player-facing text
/// written elsewhere in `lib/presentation/`.
library;

import 'account_strings.dart';
import 'common_strings.dart';
import 'game_strings.dart';
import 'home_strings.dart';
import 'online_strings.dart';
import 'profile_strings.dart';
import 'ranks_strings.dart';

export 'account_strings.dart';
export 'common_strings.dart';
export 'game_strings.dart';
export 'home_strings.dart';
export 'online_strings.dart';
export 'profile_strings.dart';
export 'ranks_strings.dart';

class AppStrings {
  const AppStrings({
    this.common = const CommonStrings(),
    this.home = const HomeStrings(),
    this.game = const GameStrings(),
    this.profile = const ProfileStrings(),
    this.account = const AccountStrings(),
    this.online = const OnlineStrings(),
    this.ranks = const RanksStrings(),
  });

  final CommonStrings common;
  final HomeStrings home;
  final GameStrings game;
  final ProfileStrings profile;
  final AccountStrings account;
  final OnlineStrings online;
  final RanksStrings ranks;
}

/// The app's words: English (the only language at launch).
const strings = AppStrings();
