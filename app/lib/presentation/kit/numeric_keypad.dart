import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'keypad_key.dart';
import '../strings/strings.dart';

/// The *physical* digit row, not the logical one: on an AZERTY keyboard,
/// these keys produce "& é " ' ( - è _ ç à" without Shift — the player must
/// be able to type digits without Shift, as on a numeric keypad.
final physicalDigitKeys = {
  PhysicalKeyboardKey.digit0: '0',
  PhysicalKeyboardKey.digit1: '1',
  PhysicalKeyboardKey.digit2: '2',
  PhysicalKeyboardKey.digit3: '3',
  PhysicalKeyboardKey.digit4: '4',
  PhysicalKeyboardKey.digit5: '5',
  PhysicalKeyboardKey.digit6: '6',
  PhysicalKeyboardKey.digit7: '7',
  PhysicalKeyboardKey.digit8: '8',
  PhysicalKeyboardKey.digit9: '9',
  PhysicalKeyboardKey.numpad0: '0',
  PhysicalKeyboardKey.numpad1: '1',
  PhysicalKeyboardKey.numpad2: '2',
  PhysicalKeyboardKey.numpad3: '3',
  PhysicalKeyboardKey.numpad4: '4',
  PhysicalKeyboardKey.numpad5: '5',
  PhysicalKeyboardKey.numpad6: '6',
  PhysicalKeyboardKey.numpad7: '7',
  PhysicalKeyboardKey.numpad8: '8',
  PhysicalKeyboardKey.numpad9: '9',
};

/// A key of the keypad, for tests and the layout pins.
ValueKey<String> keypadKeyKey(String name) => ValueKey('keypad-$name');

/// The built-in keypad (`doc/design.md`): 1–9 on three rows, then
/// backspace / 0 / validate. Shared by the game screen and the chain's
/// last screen.
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onValidate,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onValidate;

  static const _digitRows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in _digitRows)
          Expanded(
            child: Row(
              children: [
                for (final digit in row)
                  Expanded(
                    child: KeypadKey.digit(
                      digit,
                      key: keypadKeyKey(digit),
                      onTap: () => onDigit(digit),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeypadKey.icon(
                  Icons.backspace_outlined,
                  key: keypadKeyKey('backspace'),
                  semanticLabel: strings.game.backspace,
                  onTap: onBackspace,
                  subdued: true,
                ),
              ),
              Expanded(
                child: KeypadKey.digit(
                  '0',
                  key: keypadKeyKey('0'),
                  onTap: () => onDigit('0'),
                ),
              ),
              Expanded(
                child: KeypadKey.icon(
                  Icons.check,
                  key: keypadKeyKey('submit'),
                  semanticLabel: strings.game.submit,
                  onTap: onValidate,
                  isPrimary: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
