import 'package:math_core/models/input_device.dart';
import 'package:math_trainer/core/effects/app_session_effects.dart';
import 'package:math_trainer/core/effects/effect_settings.dart';
import 'package:math_trainer/core/effects/game_sound.dart';
import 'package:math_trainer/core/effects/session_effects.dart';
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

class _RecordingHaptics implements SessionEffects {
  final List<String> felt = [];

  @override
  void keyPressed(InputDevice device) => felt.add('key ${device.name}');

  @override
  void answered({required bool correct, required int streak}) =>
      felt.add(correct ? 'correct' : 'wrong');

  @override
  void timedOut() => felt.add('timeout');
}

class _MemoryStore implements EffectSettingsStore {
  _MemoryStore([this.sound]);

  bool? sound;
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
}

void main() {
  group('AppSessionEffects', () {
    late _RecordingSound sound;
    late _RecordingHaptics haptics;
    late EffectSettings settings;
    late AppSessionEffects effects;

    setUp(() {
      sound = _RecordingSound();
      haptics = _RecordingHaptics();
      settings = EffectSettings(store: _MemoryStore());
      effects = AppSessionEffects(
        sound: sound,
        haptics: haptics,
        settings: settings,
      );
    });

    test('a game: ticks on the keypad, a chime that knows the streak, a '
        'low tone on a mistake or a timeout', () {
      effects
        ..keyPressed(InputDevice.keypad)
        ..answered(correct: true, streak: 3)
        ..answered(correct: false, streak: 0)
        ..timedOut();
      expect(sound.played, ['tick', 'correct 3', 'wrong', 'wrong']);
      expect(haptics.felt, ['key keypad', 'correct', 'wrong', 'timeout']);
    });

    test('a physical keyboard key does not tick (the player hears it)', () {
      effects.keyPressed(InputDevice.keyboard);
      expect(sound.played, isEmpty);
      expect(haptics.felt, ['key keyboard']);
    });

    test('sound off: silence, at the very next effect', () {
      settings.setSound(false);
      effects
        ..keyPressed(InputDevice.keypad)
        ..answered(correct: true, streak: 1)
        ..timedOut();
      expect(sound.played, isEmpty);
      expect(haptics.felt, hasLength(3));
    });
  });

  group('EffectSettings', () {
    test('sound is on by default, and when never set', () async {
      expect(EffectSettings(store: _MemoryStore()).sound, isTrue);
      expect((await EffectSettings.load(_MemoryStore())).sound, isTrue);
    });

    test('the stored choice is read back', () async {
      expect((await EffectSettings.load(_MemoryStore(false))).sound, isFalse);
    });

    test('a failed read keeps the default', () async {
      final store = _MemoryStore(false)..failRead = true;
      expect((await EffectSettings.load(store)).sound, isTrue);
    });

    test('a change notifies and is stored; the same value writes nothing', () {
      final store = _MemoryStore();
      final settings = EffectSettings(store: store);
      var notified = 0;
      settings.addListener(() => notified++);
      settings
        ..setSound(false)
        ..setSound(false);
      expect(settings.sound, isFalse);
      expect(notified, 1);
      expect(store.writes, 1);
      expect(store.sound, isFalse);
    });

    test('a failed write keeps the choice for this run', () async {
      final store = _MemoryStore()..failWrite = true;
      final settings = EffectSettings(store: store)..setSound(false);
      await Future<void>.delayed(Duration.zero);
      expect(settings.sound, isFalse);
    });
  });
}
