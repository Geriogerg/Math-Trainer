import 'package:flutter_test/flutter_test.dart';
import 'package:math_core/challenges/chain.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_chain_setup_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const store = SharedPreferencesChainSetupStore();

  test('null until something is saved', () async {
    expect(await store.load(), isNull);
  });

  test('save() then load() finds the same setup', () async {
    final setup = ChainSetup(secondsPerScreen: 3, operations: 15);
    await store.save(setup);
    expect(await store.load(), setup);
  });

  test('a choice this build does not offer: the default (null)', () async {
    SharedPreferences.setMockInitialValues({
      'chain_setup_seconds_per_screen': 4,
      'chain_setup_operations': 10,
    });
    expect(await store.load(), isNull);
  });
}
