/// Digits grouped by three with a space (`doc/levels.md` section 6, plan
/// v3.1 Levels phase commit 5): "12 500", "1 234 567". A space rather than a
/// comma: French-speaking players read "4,789" as a decimal, and the space
/// is the SI's group separator. A plain space, drawn by the digit face (a
/// narrow no-break space is not in its subset, and a fallback face would
/// grow the line); the texts that hold one never wrap.
String groupedDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// [n] as shown: grouped digits, a minus sign (U+2212) for a negative.
String groupedNumber(int n) =>
    n < 0 ? '−${groupedDigits('${-n}')}' : groupedDigits('$n');
