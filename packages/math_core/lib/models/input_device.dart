/// How one answer was typed (owner decision after Phase 3a): Phase 3b
/// derives response-time targets per operation, and a physical keyboard is
/// faster than the on-screen keypad — mixing both would skew them.
///
/// Names are stored (local answers, uploads, the server's copy): never
/// rename a value.
enum InputDevice {
  /// The on-screen keypad (touch, or a mouse on a desktop).
  keypad,

  /// A physical keyboard (digit row, numeric keypad, Enter, Backspace).
  keyboard,

  /// Both within the same answer.
  mixed;

  /// What a question has used once a key from [used] is pressed, given
  /// [current], what it used before (`null`: no key yet).
  static InputDevice combine(InputDevice? current, InputDevice used) =>
      current == null || current == used ? used : mixed;
}
