import 'package:math_core/models/input_device.dart';
import 'package:math_trainer/core/effects/app_session_effects.dart';
import 'package:math_trainer/core/effects/effect_settings.dart';
import 'package:math_trainer/core/effects/game_haptics.dart';
import 'package:math_trainer/core/effects/game_sound.dart';
import 'package:test/test.dart';

class _RecordingSound implements GameSound {
  final List<String> played = [];

  @override
  void keyTick() => played.add('tick');

  @override
  void correct(int streak) => played.add('correct $streak');

  @override
  void wrong() => played.add('wrong');

  @override
  void levelUp() => played.add('levelUp');
}

class _RecordingHaptics implements GameHaptics {
  final List<String> felt = [];

  @override
  bool get supported => true;

  @override
  void key() => felt.add('key');

  @override
  void success() => felt.add('success');

  @override
  void warning() => felt.add('warning');
}

class _MemoryStore implements EffectSettingsStore {
  _MemoryStore({this.sound, this.haptics});

  bool? sound;
  bool? haptics;
  bool failRead = false;
  bool failWrite = false;
  int writes = 0;

  @override
  Future<bool?> readSound() async {
    if (failRead) throw Exception('storage unavailable');
    return sound;
  }

  @override
  Future<void> writeSound(bool on) async {
    writes++;
    if (failWrite) throw Exception('storage full');
    sound = on;
  }

  @override
  Future<bool?> readHaptics() async {
    if (failRead) throw Exception('storage unavailable');
    return haptics;
  }

  @override
  Future<void> writeHaptics(bool on) async {
    writes++;
    if (failWrite) throw Exception('storage full');
    haptics = on;
  }
}

void main() {
  group('AppSessionEffects', () {
    late _RecordingSound sound;
    late _RecordingHaptics haptics;
    late EffectSettings settings;

    AppSessionEffects effects() =>
        AppSessionEffects(sound: sound, haptics: haptics, settings: settings);

    setUp(() {
      sound = _RecordingSound();
      haptics = _RecordingHaptics();
      settings = EffectSettings(store: _MemoryStore());
    });

    test('a game: the keypad ticks and taps, a right answer chimes with '
        'its streak and pulses, a mistake or a timeout warns', () {
      effects()
        ..keyPressed(InputDevice.keypad)
        ..answered(correct: true, streak: 3)
        ..answered(correct: false, streak: 0)
        ..timedOut();
      expect(sound.played, ['tick', 'correct 3', 'wrong', 'wrong']);
      expect(haptics.felt, ['key', 'success', 'warning', 'warning']);
    });

    test('a physical keyboard key: no tick, no tap', () {
      effects().keyPressed(InputDevice.keyboard);
      expect(sound.played, isEmpty);
      expect(haptics.felt, isEmpty);
    });

    test('each switch silences only its own effect, at the next one', () {
      settings.setSound(false);
      effects()
        ..keyPressed(InputDevice.keypad)
        ..answered(correct: true, streak: 1);
      expect(sound.played, isEmpty);
      expect(haptics.felt, ['key', 'success']);

      settings
        ..setSound(true)
        ..setHaptics(false);
      effects().timedOut();
      expect(sound.played, ['wrong']);
      expect(haptics.felt, ['key', 'success']);
    });

    test('a device that cannot vibrate never asks, whatever the switch', () {
      settings = EffectSettings(store: _MemoryStore(), hapticsSupported: false);
      effects()
        ..keyPressed(InputDevice.keypad)
        ..answered(correct: false, streak: 0);
      expect(haptics.felt, isEmpty);
      expect(settings.hapticsChosen, isTrue);
      expect(settings.haptics, isFalse);
    });
  });

  group('EffectSettings', () {
    test('both on by default, and when never set', () async {
      final fresh = EffectSettings(store: _MemoryStore());
      expect([fresh.sound, fresh.haptics], [true, true]);
      final loaded = await EffectSettings.load(
        _MemoryStore(),
        hapticsSupported: true,
      );
      expect([loaded.sound, loaded.haptics], [true, true]);
    });

    test('the stored choices are read back', () async {
      final loaded = await EffectSettings.load(
        _MemoryStore(sound: false, haptics: false),
        hapticsSupported: true,
      );
      expect([loaded.sound, loaded.haptics], [false, false]);
    });

    test('a failed read keeps the defaults', () async {
      final store = _MemoryStore(sound: false)..failRead = true;
      final loaded = await EffectSettings.load(store, hapticsSupported: true);
      expect([loaded.sound, loaded.haptics], [true, true]);
    });

    test('a change notifies and is stored; the same value writes nothing', () {
      final store = _MemoryStore();
      final settings = EffectSettings(store: store);
      var notified = 0;
      settings.addListener(() => notified++);
      settings
        ..setSound(false)
        ..setSound(false)
        ..setHaptics(false);
      expect([settings.sound, settings.haptics], [false, false]);
      expect(notified, 2);
      expect(store.writes, 2);
      expect([store.sound, store.haptics], [false, false]);
    });

    test('a failed write keeps the choice for this run', () async {
      final store = _MemoryStore()..failWrite = true;
      final settings = EffectSettings(store: store)..setSound(false);
      await Future<void>.delayed(Duration.zero);
      expect(settings.sound, isFalse);
    });
  });
}
