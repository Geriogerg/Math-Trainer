import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/app.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/state/language.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_language_store.dart';
import 'package:math_trainer/presentation/strings/strings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_account_repository.dart';
import 'fake_profile_repository.dart';

class _Languages implements LanguageStore {
  AppLanguage? saved;

  @override
  Future<AppLanguage?> load() async => saved;

  @override
  Future<void> save(AppLanguage language) async => saved = language;
}

/// Phase 6d (plan v4.2): French, chosen in Profile, the browser's language
/// until then.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => appLanguage.value = AppLanguage.english);

  test('the browser decides until the player chooses: French for any French '
      'locale', () {
    expect(AppLanguage.forLocale('fr'), AppLanguage.french);
    expect(AppLanguage.forLocale('FR'), AppLanguage.french);
    expect(AppLanguage.forLocale('en'), AppLanguage.english);
    expect(AppLanguage.forLocale('de'), AppLanguage.english);
    expect(AppLanguage.byCode('fr'), AppLanguage.french);
    expect(AppLanguage.byCode('xx'), isNull);
    expect(AppLanguage.byCode(null), isNull);
  });

  test('stored codes never change; the store keeps the choice', () async {
    expect([for (final l in AppLanguage.values) l.code], ['en', 'fr']);
    const store = SharedPreferencesLanguageStore();
    expect(await store.load(), isNull);
    await store.save(AppLanguage.french);
    expect(await store.load(), AppLanguage.french);
    // Where the loading screen looks for it (web/index.html).
    expect(SharedPreferencesLanguageStore.key, 'language');
  });

  test('the words follow the language', () {
    appLanguage.value = AppLanguage.french;
    expect(strings.common.start, 'Commencer');
    appLanguage.value = AppLanguage.english;
    expect(strings.common.start, 'Start');
  });

  testWidgets('Profile → Français: the whole app in French at once, the tab '
      'kept, the choice saved; Flutter\'s own words too', (tester) async {
    tester.view.physicalSize = const Size(412, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final languages = _Languages();
    final accounts = FakeAccountRepository();
    await tester.pumpWidget(
      MathTrainerApp(
        environment: AppEnvironment(
          repository: InMemorySessionRepository(),
          playerId: 'p',
          accountRepository: accounts,
          profileRepository: FakeProfileRepository(),
          languageStore: languages,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(languages.saved, AppLanguage.french);
    // The account's emails follow (Phase 6d commit 4).
    expect(accounts.rememberedLanguages, ['fr']);
    // Still on Profile, now in French.
    expect(find.text('Réglages'), findsOneWidget);
    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Settings'), findsNothing);
    final locale = Localizations.localeOf(
      tester.element(find.text('Réglages')),
    );
    expect(locale.languageCode, 'fr');
    expect(
      MaterialLocalizations.of(
        tester.element(find.text('Réglages')),
      ).backButtonTooltip,
      'Retour',
    );

    await tester.tap(find.text('Jouer').first);
    await tester.pumpAndSettle();
    expect(find.text('Bases'), findsOneWidget);

    // And back.
    await tester.tap(find.text('Profil').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(languages.saved, AppLanguage.english);
  });
}
