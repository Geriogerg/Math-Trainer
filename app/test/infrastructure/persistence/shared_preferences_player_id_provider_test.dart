import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/infrastructure/persistence/shared_preferences_player_id_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SharedPreferencesPlayerIdProvider', () {
    test('generates an id on the first call then reuses it', () async {
      final provider = SharedPreferencesPlayerIdProvider();

      final first = await provider.currentPlayerId();
      final second = await provider.currentPlayerId();

      expect(first, second);
    });

    test('the id persists beyond the provider instance', () async {
      final first = await SharedPreferencesPlayerIdProvider().currentPlayerId();
      final second = await SharedPreferencesPlayerIdProvider()
          .currentPlayerId();

      expect(first, second);
    });
  });
}
