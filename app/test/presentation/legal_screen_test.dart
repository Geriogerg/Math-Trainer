import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/persistence/abandoned_guest_cleanup.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/presentation/screens/legal_screen.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/screens/save_progress_screen.dart';
import 'package:math_trainer/presentation/strings/legal/legal_details.dart';
import 'package:math_trainer/presentation/strings/legal/legal_texts.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

/// The privacy policy and the legal notice (Phase 6c commit 2, plan v4.1;
/// review B1).
void main() {
  final marks = RegExp('⟦([a-zA-Z]+)⟧');
  const en = EnglishLegalTexts();
  const fr = FrenchLegalTexts();

  String all(List<LegalSection> sections) => [
    for (final (heading, paragraphs) in sections) ...[heading, ...paragraphs],
  ].join('\n');

  List<List<String>> marksOf(List<LegalSection> sections) => [
    for (final (_, paragraphs) in sections)
      [
        for (final p in paragraphs)
          for (final m in marks.allMatches(p)) m[1]!,
      ],
  ];

  group('the texts', () {
    test('both languages have the same sections and the same owner details '
        'in each', () {
      for (final (a, b) in [(en.privacy, fr.privacy), (en.notice, fr.notice)]) {
        expect(b.length, a.length);
        for (final (i, (_, paragraphs)) in a.indexed) {
          expect(b[i].$2.length, paragraphs.length, reason: a[i].$1);
        }
        expect(marksOf(b), marksOf(a));
      }
    });

    test('every mark names a detail, and every detail is used', () {
      final used = <String>{};
      for (final texts in [en, fr]) {
        for (final text in [all(texts.privacy), all(texts.notice)]) {
          for (final m in marks.allMatches(text)) {
            expect(
              LegalDetail.values.map((d) => d.name),
              contains(m[1]),
              reason: m[0],
            );
            used.add(m[1]!);
          }
          // A broken mark would show its brackets to players.
          expect(text.replaceAll(marks, ''), isNot(contains('⟦')));
        }
      }
      expect(used, {for (final d in LegalDetail.values) d.name});
    });

    test('what the policy states is what the code does', () {
      final days = abandonedGuestRetention.inDays;
      expect(all(en.privacy), contains('unused for $days days'));
      expect(all(fr.privacy), contains('inutilisé pendant $days jours'));
      // The buttons it names exist with these words, in each language
      // (profile_strings.dart, Phase 6d).
      for (final (text, words) in [
        (all(en.privacy), englishStrings.profile),
        (all(fr.privacy), frenchStrings.profile),
      ]) {
        expect(text, contains(words.deleteButton(guest: true)));
        expect(text, contains(words.deleteButton(guest: false)));
        expect(text, contains('15'));
      }
      // Duels, friends and the per-answer data are described (plan v4.1).
      for (final word in ['duel', 'friend', 'each question', 'how long']) {
        expect(all(en.privacy).toLowerCase(), contains(word));
      }
    });
  });

  /// Every paragraph as drawn (a placeholder's brackets, not its spoken
  /// label).
  String shown(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(find.byType(Text)))
      text.data ??
          text.textSpan?.toPlainText(includeSemanticsLabels: false) ??
          '',
  ].join(' | ');

  Future<void> pumpLegal(
    WidgetTester tester,
    LegalPage page, {
    Map<LegalDetail, Map<String, String>> details = const {},
    String languageCode = 'en',
  }) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: LegalScreen(
          page: page,
          details: details,
          languageCode: languageCode,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('details not given: visible placeholders under a Draft banner', (
    tester,
  ) async {
    await pumpLegal(tester, LegalPage.notice);
    expect(find.text('Legal notice'), findsOneWidget);
    expect(find.textContaining('Draft:'), findsOneWidget);
    // Shown in brackets, said as "not filled in yet".
    expect(shown(tester), contains('[publisher]'));
    expect(shown(tester), contains('[contact email]'));
    expect(find.textContaining('Not filled in yet: publisher'), findsWidgets);
  });

  testWidgets('details given: shown in their place, no banner', (tester) async {
    await pumpLegal(
      tester,
      LegalPage.notice,
      details: {
        for (final d in LegalDetail.values)
          d: {'en': 'EN-${d.name}', 'fr': 'FR-${d.name}'},
      },
    );
    expect(find.textContaining('Draft:'), findsNothing);
    expect(shown(tester), isNot(contains('[')));
    expect(shown(tester), contains('EN-contactEmail'));
    // The other language takes its own values.
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Mentions légales'), findsOneWidget);
    expect(shown(tester), contains('FR-contactEmail'));
  });

  testWidgets('English or French, French first on a French device', (
    tester,
  ) async {
    await pumpLegal(tester, LegalPage.privacy, languageCode: 'fr');
    expect(find.text('Politique de confidentialité'), findsOneWidget);
    expect(find.text('Responsable du traitement'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Who is responsible'), findsOneWidget);
    // Another language: English.
    await pumpLegal(tester, LegalPage.privacy, languageCode: 'de');
    expect(find.text('Privacy policy'), findsOneWidget);
  });

  testWidgets('reachable from Profile: both pages', (tester) async {
    tester.view.physicalSize = const Size(412, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'p',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Legal notice'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
  });

  testWidgets('reachable from the save form, which asks for the age', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: SaveProgressScreen(
          accountRepository: FakeAccountRepository(),
          profileRepository: FakeProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('I am 15 or older'), findsOneWidget);
    await tester.tap(find.text('Legal notice'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
  });
}
