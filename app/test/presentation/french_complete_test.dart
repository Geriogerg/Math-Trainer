import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/account/account_exception.dart';
import 'package:math_core/account/display_name.dart';
import 'package:math_core/duel/duel_mode.dart';
import 'package:math_core/method/method.dart';
import 'package:math_core/models/exercise_type.dart';
import 'package:math_core/models/operation_type.dart';
import 'package:math_core/patterns/pattern_family.dart';
import 'package:math_core/strategies/strategy.dart';
import 'package:math_core/validation/session_validation.dart';
import 'package:math_trainer/presentation/strings/strings.dart';
import 'package:math_trainer/presentation/strings/tips.dart';

import 'source_literals.dart';

/// Phase 6d commit 5 — plan v4.2's exit: "a test fails on any missing
/// translation". Three layers:
///
/// - **missing**: each area is an interface and each French class
///   implements it, so a member without French does not compile; the
///   tables are exhaustive switches, likewise. The tests below hold that
///   design in place (no French class borrowing from an English one, every
///   area of [frenchStrings] French);
/// - **untranslated**: no French source holds a word-holding literal that
///   its English area also holds, and no table gives the same words in both
///   languages, except the entries of [_sameInBoth], each with its reason;
/// - **shown**: every screen rendered in French at 360 px shows no English
///   word (`french_screens_test.dart`).

/// Each area's English file (beside `strings.dart`) and its French file
/// (`french/`).
const _areas = {
  'account_strings.dart': 'account_fr.dart',
  'common_strings.dart': 'common_fr.dart',
  'game_strings.dart': 'game_fr.dart',
  'home_strings.dart': 'home_fr.dart',
  'labels_strings.dart': 'labels_fr.dart',
  'online_strings.dart': 'online_fr.dart',
  'profile_strings.dart': 'profile_fr.dart',
  'ranks_strings.dart': 'ranks_fr.dart',
  'spoken_strings.dart': 'spoken_fr.dart',
  'tip_strings.dart': 'tips_fr.dart',
};

/// What is written the same in both languages (interpolations taken out,
/// trimmed).
const _sameInBoth = {
  // French words spelled as the English ones.
  'OK', 'Score', 'Mode', 'Questions', 'questions.', 'Tables', 'Duels',
  'Placement', 'Vibration', 'Top 100', 'Addition', 'Division',
  'Multiplication', 'Doubles',
  // What a screen reader says for "+": "plus" in both.
  'plus',
  // Notation, not language.
  '(a + b)² = a² + 2ab + b².',
  // The configuration error's commands (a developer's screen).
  '--dart-define-from-file=dart_defines.json',
  'dart run sqflite_common_ffi_web:setup',
};

const _strings = 'lib/presentation/strings';

void main() {
  test('no French string is an English one left untranslated', () {
    final untranslated = <String>[];
    for (final MapEntry(key: english, value: french) in _areas.entries) {
      final englishTexts = {
        for (final (_, text) in wordLiteralsOf('$_strings/$english'))
          _bare(text),
      };
      for (final (line, text) in wordLiteralsOf('$_strings/french/$french')) {
        final bare = _bare(text);
        if (englishTexts.contains(bare) && !_sameInBoth.contains(bare)) {
          untranslated.add('french/$french:$line: $text');
        }
      }
    }
    expect(untranslated, isEmpty, reason: untranslated.join('\n'));
  });

  test('every area has its French file, and each stands alone', () {
    final frenchFiles = Directory(
      '$_strings/french',
    ).listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toSet();
    expect(frenchFiles, _areas.values.toSet());
    for (final french in _areas.values) {
      final source = File('$_strings/french/$french').readAsStringSync();
      // A French class never reads, extends or mixes in an English one: a
      // member it lacks must fail to compile, not fall back to English.
      expect(
        RegExp(r'\bEnglish\w+').hasMatch(source),
        isFalse,
        reason: '$french names an English class',
      );
      final classes = RegExp(
        r'^class (French\w+)([^{]*)\{',
        multiLine: true,
      ).allMatches(source).toList();
      expect(classes, isNotEmpty, reason: french);
      for (final c in classes) {
        expect(
          c.group(2),
          allOf(contains('implements'), isNot(contains('extends'))),
          reason: '${c.group(1)} in $french',
        );
      }
    }
  });

  test('every area of the French strings is a French class', () {
    final areas = [
      frenchStrings.common,
      frenchStrings.home,
      frenchStrings.game,
      frenchStrings.profile,
      frenchStrings.account,
      frenchStrings.online,
      frenchStrings.ranks,
      frenchStrings.labels,
      frenchStrings.spoken,
      frenchStrings.tips,
    ];
    for (final area in areas) {
      expect('${area.runtimeType}', startsWith('French'));
    }
    expect(stringsFor(AppLanguage.french), same(frenchStrings));
  });

  test('every entry of the tables is French', () {
    final en = englishStrings, fr = frenchStrings;
    final same = <String>[];
    void check(String what, String english, String french) {
      expect(french.trim(), isNotEmpty, reason: what);
      if (english == french && !_sameInBoth.contains(french.trim())) {
        same.add('$what: $french');
      }
    }

    for (final v in ExerciseType.values) {
      check('$v', en.labels.exerciseType(v), fr.labels.exerciseType(v));
      check(
        'fallback $v',
        en.labels.operationFallback(v),
        fr.labels.operationFallback(v),
      );
    }
    for (final v in PatternFamily.values) {
      check('$v', en.labels.patternFamily(v), fr.labels.patternFamily(v));
    }
    for (final v in Strategy.values) {
      check('$v', en.labels.strategy(v), fr.labels.strategy(v));
    }
    for (final v in MethodFallback.values) {
      check('$v', en.labels.fallback(v), fr.labels.fallback(v));
    }
    for (final v in AccountFailure.values) {
      check('$v', en.labels.accountFailure(v), fr.labels.accountFailure(v));
    }
    for (final v in DisplayNameProblem.values) {
      check('$v', en.labels.nameProblem(v), fr.labels.nameProblem(v));
    }
    for (final v in [...RejectionReason.values, null]) {
      check('$v', en.labels.uploadRefusal(v), fr.labels.uploadRefusal(v));
    }
    for (final v in DuelMode.values) {
      check('$v', en.labels.duelMode(v), fr.labels.duelMode(v));
      check(
        'sent $v',
        en.labels.unfinishedDuelsSent(en.labels.duelMode(v), 2),
        fr.labels.unfinishedDuelsSent(fr.labels.duelMode(v), 2),
      );
    }
    for (final score in [0.0, 0.5, 1.0]) {
      check('result $score', en.labels.result(score), fr.labels.result(score));
    }
    for (final v in OperationType.values) {
      // "plus" is the same word in both (see [_sameInBoth]).
      check('$v', en.spoken.operator(v), fr.spoken.operator(v));
    }
    for (final v in TipId.values) {
      check('$v', en.tips.text(v), fr.tips.text(v));
    }
    expect(same, isEmpty, reason: same.join('\n'));
  });

  test('the check finds an untranslated string (its own check)', () {
    expect(_bare(r'${n} questions.'), 'questions.');
    expect(_sameInBoth.contains(_bare('Play')), isFalse);
  });
}

String _bare(String text) => withoutInterpolations(text).trim();
