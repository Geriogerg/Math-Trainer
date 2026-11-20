import 'dart:js_interop';

import '../../core/effects/game_sound.dart';

/// The game's sounds in the browser (Phase 5 commit 4): synthesised with
/// the Web Audio API — no sound file to download or license (self-made by
/// construction, `doc/decisions.md`).
///
/// - **Unlocked on the first tap or key** (browsers allow audio only after
///   a gesture): the context is created then; earlier sounds are skipped.
/// - **Silent while the page is hidden**: the context is suspended, and
///   nothing is scheduled.
/// - Never throws, never waits: a sound is a few audio nodes scheduled on
///   the audio thread.
GameSound createGameSound() => _WebAudioGameSound();

class _WebAudioGameSound implements GameSound {
  _WebAudioGameSound() {
    try {
      _listenForFirstGesture();
      _document.addEventListener('visibilitychange', _onVisibility.toJS);
    } catch (_) {
      // No document (a worker): silence.
    }
  }

  _AudioContext? _context;
  JSFunction? _unlockListener;

  void _listenForFirstGesture() {
    final listener = ((JSAny _) => _unlock()).toJS;
    _unlockListener = listener;
    // Capture phase: before Flutter handles the same tap.
    _window.addEventListener('pointerdown', listener, true.toJS);
    _window.addEventListener('keydown', listener, true.toJS);
  }

  void _unlock() {
    try {
      _context ??= _AudioContext();
      if (!_document.hidden) _context!.resume();
      final listener = _unlockListener;
      if (listener != null) {
        _window.removeEventListener('pointerdown', listener, true.toJS);
        _window.removeEventListener('keydown', listener, true.toJS);
        _unlockListener = null;
      }
    } catch (_) {
      // No Web Audio: silence.
    }
  }

  void _onVisibility(JSAny _) {
    final context = _context;
    if (context == null) return;
    try {
      if (_document.hidden) {
        context.suspend();
      } else {
        context.resume();
      }
    } catch (_) {}
  }

  /// The context, when a sound may play now.
  _AudioContext? get _ready {
    final context = _context;
    if (context == null || _document.hidden || context.state != 'running') {
      return null;
    }
    return context;
  }

  /// One soft tone: a 5 ms attack (no click), an exponential decay.
  void _tone(
    _AudioContext context, {
    required double frequency,
    required double duration,
    required double peak,
    double delay = 0,
    String wave = 'sine',
    double? glideTo,
  }) {
    final start = context.currentTime + delay;
    final oscillator = context.createOscillator()..type = wave;
    oscillator.frequency.setValueAtTime(frequency, start);
    if (glideTo != null) {
      oscillator.frequency.exponentialRampToValueAtTime(
        glideTo,
        start + duration,
      );
    }
    final gain = context.createGain();
    gain.gain
      ..setValueAtTime(0.0001, start)
      ..exponentialRampToValueAtTime(peak, start + 0.005)
      ..exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(gain);
    gain.connect(context.destination);
    oscillator.start(start);
    oscillator.stop(start + duration + 0.02);
  }

  void _play(void Function(_AudioContext context) sound) {
    final context = _ready;
    if (context == null) return;
    try {
      sound(context);
    } catch (_) {}
  }

  @override
  void keyTick() => _play(
    (c) => _tone(
      c,
      frequency: 1500,
      duration: 0.018,
      peak: 0.03,
      wave: 'triangle',
    ),
  );

  @override
  void correct(int streak) => _play((c) {
    final note = _streakNotes[(streak - 1).clamp(0, _streakNotes.length - 1)];
    _tone(c, frequency: note, duration: 0.14, peak: 0.1);
    // A quiet octave on top: brighter without being louder.
    _tone(c, frequency: note * 2, duration: 0.09, peak: 0.025);
  });

  @override
  void wrong() => _play(
    (c) => _tone(
      c,
      frequency: 196,
      duration: 0.17,
      peak: 0.09,
      wave: 'triangle',
      glideTo: 165,
    ),
  );

  @override
  void levelUp() => _play((c) {
    for (final (i, note) in _levelUpNotes.indexed) {
      _tone(c, frequency: note, duration: 0.2, peak: 0.08, delay: i * 0.07);
    }
  });
}

/// The correct chime climbs a major pentatonic scale from C5 with the
/// streak — no step ever clashes — and stops climbing at 10 in a row.
const _streakNotes = [
  523.25, 587.33, 659.25, 783.99, 880.00, // C5 D5 E5 G5 A5
  1046.50, 1174.66, 1318.51, 1567.98, 1760.00, // C6 D6 E6 G6 A6
];

/// Level-up: C5 E5 G5 C6, rising.
const _levelUpNotes = [523.25, 659.25, 783.99, 1046.50];

@JS('window')
external _EventTarget get _window;

@JS('document')
external _Document get _document;

extension type _EventTarget._(JSObject _) implements JSObject {
  external void addEventListener(
    String type,
    JSFunction listener, [
    JSAny? options,
  ]);
  external void removeEventListener(
    String type,
    JSFunction listener, [
    JSAny? options,
  ]);
}

extension type _Document._(JSObject _) implements _EventTarget {
  external bool get hidden;
}

@JS('AudioContext')
extension type _AudioContext._(JSObject _) implements JSObject {
  external factory _AudioContext();
  external double get currentTime;
  external String get state;
  external JSObject get destination;
  external _Oscillator createOscillator();
  external _Gain createGain();
  external JSPromise<JSAny?> resume();
  external JSPromise<JSAny?> suspend();
}

extension type _AudioParam._(JSObject _) implements JSObject {
  external void setValueAtTime(double value, double time);
  external void exponentialRampToValueAtTime(double value, double time);
}

extension type _Oscillator._(JSObject _) implements JSObject {
  external set type(String value);
  external _AudioParam get frequency;
  external JSObject connect(JSObject destination);
  external void start(double when);
  external void stop(double when);
}

extension type _Gain._(JSObject _) implements JSObject {
  external _AudioParam get gain;
  external JSObject connect(JSObject destination);
}
