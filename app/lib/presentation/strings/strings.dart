/// Every word the app shows a player, in one place (Phase 6b commit 7,
/// review m18; plan v4.0: "strings in one place, English at launch, French
/// right after").
///
/// Screens read `strings.<area>.<name>`. Each area is an interface with
/// one class per language — the owner's rule (plan v4.1): **a missing
/// translation fails to compile** (Phase 6d), as the legal pages
/// (`legal/legal_texts.dart`). Kept as Dart, not ARB files: no
/// context to thread through, enum labels as exhaustive switches, and tests
/// that need no localisation setup.
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
import 'package:flutter/foundation.dart' show ValueNotifier;
import '../../core/state/language.dart';
import 'french/common_fr.dart';
import 'french/home_fr.dart';
import 'french/game_fr.dart';
import 'french/profile_fr.dart';
import 'french/account_fr.dart';
import 'french/online_fr.dart';
import 'french/ranks_fr.dart';
import 'labels_strings.dart';
import 'spoken_strings.dart';
import 'tip_strings.dart';
import 'french/labels_fr.dart';
import 'french/spoken_fr.dart';
import 'french/tips_fr.dart';

export 'account_strings.dart';
export 'common_strings.dart';
export 'game_strings.dart';
export 'home_strings.dart';
export 'online_strings.dart';
export 'profile_strings.dart';
export 'ranks_strings.dart';
export 'labels_strings.dart';
export 'spoken_strings.dart';
export 'tip_strings.dart';
export '../../core/state/language.dart' show AppLanguage;

/// The app's words in one language: one class per area.
class AppStrings {
  const AppStrings({
    required this.common,
    required this.home,
    required this.game,
    required this.profile,
    required this.account,
    required this.online,
    required this.ranks,
    required this.labels,
    required this.spoken,
    required this.tips,
  });

  final CommonStrings common;
  final HomeStrings home;
  final GameStrings game;
  final ProfileStrings profile;
  final AccountStrings account;
  final OnlineStrings online;
  final RanksStrings ranks;

  /// The tables: operations, Method names, messages, duel words (6d).
  final LabelStrings labels;

  /// What a screen reader says for a prompt.
  final SpokenStrings spoken;

  /// The Tips page's words.
  final TipStrings tips;
}

/// English.
const englishStrings = AppStrings(
  common: EnglishCommonStrings(),
  home: EnglishHomeStrings(),
  game: EnglishGameStrings(),
  profile: EnglishProfileStrings(),
  account: EnglishAccountStrings(),
  online: EnglishOnlineStrings(),
  ranks: EnglishRanksStrings(),
  labels: EnglishLabelStrings(),
  spoken: EnglishSpokenStrings(),
  tips: EnglishTipStrings(),
);

/// French (Phase 6d).
const frenchStrings = AppStrings(
  common: FrenchCommonStrings(),
  home: FrenchHomeStrings(),
  game: FrenchGameStrings(),
  profile: FrenchProfileStrings(),
  account: FrenchAccountStrings(),
  online: FrenchOnlineStrings(),
  ranks: FrenchRanksStrings(),
  labels: FrenchLabelStrings(),
  spoken: FrenchSpokenStrings(),
  tips: FrenchTipStrings(),
);

/// The words of [language].
AppStrings stringsFor(AppLanguage language) => switch (language) {
  AppLanguage.english => englishStrings,
  AppLanguage.french => frenchStrings,
};

/// The interface's language (Phase 6d): the browser's at start, the
/// player's choice once made (Profile). `MathTrainerApp` listens and
/// redraws every screen in it.
final appLanguage = ValueNotifier<AppLanguage>(AppLanguage.english);

/// The app's words, in [appLanguage].
AppStrings get strings => stringsFor(appLanguage.value);

/// A language's own name, the same in every language (the switch).
String languageName(AppLanguage language) => switch (language) {
  AppLanguage.english => 'English',
  AppLanguage.french => 'Français',
};
