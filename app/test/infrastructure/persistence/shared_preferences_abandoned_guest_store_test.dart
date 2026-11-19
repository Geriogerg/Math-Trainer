import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_abandoned_guest_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('records once, loads in UTC, forgets', () async {
    const store = SharedPreferencesAbandonedGuestStore();
    expect(await store.load(), isEmpty);

    await store.record('g1', DateTime.utc(2026, 11, 1));
    await store.record('g1', DateTime.utc(2026, 12, 1)); // kept: the first
    await store.record('g2', DateTime.utc(2026, 11, 2));
    expect(await const SharedPreferencesAbandonedGuestStore().load(), {
      'g1': DateTime.utc(2026, 11, 1),
      'g2': DateTime.utc(2026, 11, 2),
    });

    await store.forget('g1');
    expect((await store.load()).keys, ['g2']);
  });

  test('a corrupted value reads as empty, never throws', () async {
    SharedPreferences.setMockInitialValues({'abandoned_guests': 'not json'});
    expect(await const SharedPreferencesAbandonedGuestStore().load(), isEmpty);
  });
}
