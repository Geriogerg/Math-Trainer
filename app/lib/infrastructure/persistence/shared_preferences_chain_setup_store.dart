import 'package:shared_preferences/shared_preferences.dart';

import 'package:math_core/challenges/chain.dart';
import 'package:math_core/persistence/chain_setup_store.dart';

class SharedPreferencesChainSetupStore implements ChainSetupStore {
  const SharedPreferencesChainSetupStore();

  static const _secondsKey = 'chain_setup_seconds_per_screen';
  static const _operationsKey = 'chain_setup_operations';

  @override
  Future<ChainSetup?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_secondsKey);
    final operations = prefs.getInt(_operationsKey);
    if (seconds == null || operations == null) return null;
    try {
      return ChainSetup(secondsPerScreen: seconds, operations: operations);
    } on ArgumentError catch (_) {
      // A choice this build does not offer: the default instead.
      return null;
    }
  }

  @override
  Future<void> save(ChainSetup setup) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_secondsKey, setup.secondsPerScreen);
    await prefs.setInt(_operationsKey, setup.operations);
  }
}
