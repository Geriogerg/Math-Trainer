/// The group separator: a narrow no-break space (U+202F) — "a thin space,
/// 2 468 in both languages" (plan v4.2, Phase 6d). Never a comma or a
/// point: French reads "4,789" as a decimal and English "4.789". No-break:
/// a number is never cut at the end of a line. The digit face draws it with
/// its thin-space glyph (`tool/fonts/subset_digits.py`), Inter natively.
const groupSeparator = '\u202f';

/// Digits grouped by three (`doc/levels.md` section 6, plan v3.1 Levels
/// phase commit 5): "12 500", "1 234 567", with [groupSeparator].
String groupedDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(groupSeparator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// [n] as shown: grouped digits, a minus sign (U+2212) for a negative.
String groupedNumber(int n) =>
    n < 0 ? '−${groupedDigits('${-n}')}' : groupedDigits('$n');
