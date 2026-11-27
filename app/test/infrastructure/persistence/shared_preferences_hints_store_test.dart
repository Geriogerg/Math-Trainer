import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/core/state/hints.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_hints_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = SharedPreferencesHintsStore();

  test('nothing seen at first', () async {
    for (final hint in Hint.values) {
      expect(await store.seen(hint), isFalse, reason: hint.name);
    }
  });

  test('markSeen() marks that hint only', () async {
    await store.markSeen(Hint.countRules);
    expect(await store.seen(Hint.countRules), isTrue);
    expect(await store.seen(Hint.firstRun), isFalse);
    expect(await store.seen(Hint.chainRules), isFalse);
  });

  test('the stored keys (never rename a Hint: it would show again)', () async {
    SharedPreferences.setMockInitialValues({
      'hint_seen_firstRun': true,
      'hint_seen_countRules': true,
      'hint_seen_chainRules': true,
      'hint_seen_duelRulesBasics': true,
      'hint_seen_duelRulesAdvanced': true,
      'hint_seen_duelRulesCount': true,
    });
    for (final hint in Hint.values) {
      expect(await store.seen(hint), isTrue, reason: hint.name);
    }
  });
}
