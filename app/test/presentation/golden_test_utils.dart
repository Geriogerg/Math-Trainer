import 'dart:io';

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_trainer/presentation/strings/brand.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

import 'source_literals.dart';

/// Loads Inter and the Material icons into the test binding. Without it,
/// `flutter test` renders with fallback fonts (generic glyphs for text,
/// empty squares for icons — the keypad's `Icons.check`/`backspace_outlined`,
/// seen when generating the first goldens): the goldens would not show the
/// real rendering.
Future<void> loadInterFontForGoldens() async {
  await _loadFont('Inter', 'assets/fonts/Inter.ttf');
  // The digit face (Phase 5 commit 1): operations, answers, keypad.
  await _loadFont(
    'Space Grotesk Digits',
    'assets/fonts/SpaceGroteskDigits.ttf',
  );
  // Key without "packages/flutter/": `uses-material-design: true` injects it
  // in this exact form into the asset manifest (flutter_tools, asset.dart,
  // kMaterialFonts), not as a regular package asset.
  await _loadFont('MaterialIcons', 'fonts/MaterialIcons-Regular.otf');
}

Future<void> _loadFont(String family, String assetKey) async {
  final data = await rootBundle.load(assetKey);
  final loader = FontLoader(family)..addFont(Future.value(data));
  await loader.load();
}

/// Fixed screen size for reproducible goldens — without it, the test
/// harness's default size (often tied to the machine) would vary the
/// captured layout.
Future<void> setGoldenSurfaceSize(
  WidgetTester tester, {
  Size size = const Size(412, 915),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// --- Phase 6d commit 5: every screen in French at 360 px. ---

/// What `MathTrainerApp` gives its `MaterialApp` for the language, for the
/// tests' own apps: Flutter's words (a back button's tooltip) in the
/// language [appLanguage] holds when the app is built.
Locale get testLocale => Locale(appLanguage.value.code);
const testLocales = [Locale('en'), Locale('fr')];
const testLocalizations = GlobalMaterialLocalizations.delegates;

/// The screen built next is in French; English again after the test.
void useFrench() {
  appLanguage.value = AppLanguage.french;
  addTearDown(() => appLanguage.value = AppLanguage.english);
}

/// Lays the screen out 360 px wide — the narrowest phone the app is made
/// for — and [height] tall (a tall surface lays a whole list out, so
/// nothing escapes the checks below), then:
///
/// - **an overflow fails the test** by itself: Flutter reports it as an
///   error, which `flutter test` turns into a failure;
/// - **no English word is shown** ([expectNoEnglishShown]);
/// - the screen matches `goldens/fr360_[name].png`, for a person to read.
Future<void> expectFrenchAt360(
  WidgetTester tester,
  String name, {
  double height = 800,
  bool settle = true,
}) async {
  expect(appLanguage.value, AppLanguage.french, reason: 'call useFrench()');
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  settle ? await tester.pumpAndSettle() : await tester.pump();
  expectNoEnglishShown(tester);
  expectNothingCut(tester);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/fr360_$name.png'),
  );
}

/// Fails on any text cut short — an ellipsis or a `maxLines` limit
/// reached, which an overflow error never reports: a string that needs
/// more room than the layout gives. A player's name may be cut (names are
/// up to 20 characters, the layout gives them what is left).
void expectNothingCut(WidgetTester tester, {Set<String> names = const {}}) {
  final cut = [
    for (final element in find.byType(RichText).evaluate())
      if (element.renderObject case final RenderParagraph paragraph
          when paragraph.didExceedMaxLines &&
              !names.contains(paragraph.text.toPlainText()))
        paragraph.text.toPlainText(),
  ];
  expect(cut, isEmpty, reason: 'Cut short at 360 px:\n${cut.join('\n')}');
}

/// Fails on any English word on screen: every text, tooltip, semantic
/// label and hint is split into words, and none may be a word that only
/// the English strings use ([englishOnlyWords]). It catches what the
/// source check (`french_complete_test.dart`) cannot: words written outside
/// the strings classes, or an English class reached in French.
void expectNoEnglishShown(WidgetTester tester) {
  final shown = <String>{};
  for (final widget in tester.allWidgets) {
    switch (widget) {
      case Text(:final data, :final textSpan):
        shown.add(data ?? textSpan?.toPlainText() ?? '');
      case RichText(:final text):
        shown.add(text.toPlainText());
      case Tooltip(:final message?):
        shown.add(message);
      case Icon(:final semanticLabel?):
        shown.add(semanticLabel);
      case Semantics(:final properties):
        shown.addAll(
          [
            properties.label,
            properties.hint,
            properties.value,
            properties.tooltip,
          ].nonNulls,
        );
      default:
        break;
    }
  }
  final english = englishOnlyWords();
  final found = <String>{
    for (final text in shown)
      for (final word in wordsOf(_withoutNames(text)))
        if (english.contains(word.toLowerCase())) '"$word" in "$text"',
  };
  expect(
    found,
    isEmpty,
    reason: 'English on a French screen:\n${found.join('\n')}',
  );
}

/// What a French screen may show that looks English but is a name: the
/// game's, the languages' in the picker (each in its own language), the
/// fonts' and their licence's (legal notice), a friend code's prefix, the
/// test players' addresses — and "fair-play", French too.
final _names = RegExp(
  [
    Brand.name,
    r'\bEnglish\b',
    'Français',
    'Space Grotesk',
    'SIL Open Font License',
    'fair-play',
    r'\bMATH-',
    r'\S+@\S+',
  ].join('|'),
);

String _withoutNames(String text) => text.replaceAll(_names, ' ');

/// The words of [text]: runs of two letters or more (apostrophes split).
Iterable<String> wordsOf(String text) =>
    RegExp('[A-Za-zÀ-ÖØ-öø-ÿŒœ]{2,}').allMatches(text).map((m) => m.group(0)!);

/// The words the English strings use and the French ones never do, lower
/// case: from the literals of `lib/presentation/strings/` (English: the
/// areas and tables; French: `french/`). The legal pages hold both
/// languages in one file and are checked by their own test.
Set<String> englishOnlyWords() => _englishOnly ??= () {
  final english = <String>{}, french = <String>{};
  for (final file in Directory(
    'lib/presentation/strings',
  ).listSync(recursive: true).whereType<File>()) {
    final path = file.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || path.contains('/legal/')) continue;
    final words = path.contains('/french/') ? french : english;
    for (final (_, _, text) in literalsOf(path)) {
      words.addAll(
        wordsOf(withoutInterpolations(text)).map((w) => w.toLowerCase()),
      );
    }
  }
  return english.difference(french);
}();
Set<String>? _englishOnly;
