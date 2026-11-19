import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_placement_skip_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a skip is remembered per player', () async {
    const store = SharedPreferencesPlacementSkipStore();
    expect(await store.hasSkipped('guest-a'), isFalse);

    await store.markSkipped('guest-a');

    expect(await store.hasSkipped('guest-a'), isTrue);
    expect(await store.hasSkipped('account-b'), isFalse);
    // A new instance reads the same storage.
    expect(
      await const SharedPreferencesPlacementSkipStore().hasSkipped('guest-a'),
      isTrue,
    );
  });
}
