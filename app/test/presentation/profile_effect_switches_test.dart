import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/persistence/in_memory_session_repository.dart';
import 'package:math_trainer/composition_root.dart';
import 'package:math_trainer/core/effects/effect_settings.dart';
import 'package:math_trainer/presentation/screens/profile_screen.dart';
import 'package:math_trainer/presentation/theme/app_theme.dart';

import '../fake_account_repository.dart';
import '../fake_profile_repository.dart';

class _EffectStore implements EffectSettingsStore {
  bool? sound;
  bool? haptics;

  @override
  Future<bool?> readSound() async => sound;

  @override
  Future<void> writeSound(bool on) async => sound = on;

  @override
  Future<bool?> readHaptics() async => haptics;

  @override
  Future<void> writeHaptics(bool on) async => haptics = on;
}

/// Phase 5: the game's effects are switched in Profile, per device.
void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    EffectSettings? settings,
  }) async {
    tester.view.physicalSize = const Size(412, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: ProfileScreen(
            environment: AppEnvironment(
              repository: InMemorySessionRepository(),
              playerId: 'test-player',
              accountRepository: FakeAccountRepository(),
              profileRepository: FakeProfileRepository(),
              effectSettings: settings,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the sound switch: on by default, remembered', (tester) async {
    final store = _EffectStore();
    final settings = EffectSettings(store: store);
    await pumpProfile(tester, settings: settings);

    final sound = find.widgetWithText(SwitchListTile, 'Sound');
    expect(tester.widget<SwitchListTile>(sound).value, isTrue);
    await tester.ensureVisible(sound);
    await tester.tap(sound);
    await tester.pump();

    expect(settings.sound, isFalse);
    expect(store.sound, isFalse);
    expect(tester.widget<SwitchListTile>(sound).value, isFalse);
  });

  testWidgets('the vibration switch: on by default, remembered', (
    tester,
  ) async {
    final store = _EffectStore();
    final settings = EffectSettings(store: store);
    await pumpProfile(tester, settings: settings);

    final vibration = find.widgetWithText(SwitchListTile, 'Vibration');
    expect(tester.widget<SwitchListTile>(vibration).value, isTrue);
    await tester.ensureVisible(vibration);
    await tester.tap(vibration);
    await tester.pump();

    expect(settings.haptics, isFalse);
    expect(store.haptics, isFalse);
  });

  testWidgets('a browser that cannot vibrate: the switch is off and '
      'disabled (labels only, Redesign phase)', (tester) async {
    await pumpProfile(
      tester,
      settings: EffectSettings(store: _EffectStore(), hapticsSupported: false),
    );
    final vibration = find.widgetWithText(SwitchListTile, 'Vibration');
    final tile = tester.widget<SwitchListTile>(vibration);
    expect(tile.value, isFalse);
    expect(tile.onChanged, isNull);
  });

  testWidgets('no effect settings (tests, tools): no switches', (tester) async {
    await pumpProfile(tester);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
