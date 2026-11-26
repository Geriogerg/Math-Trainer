/// Player names are public content (plan 6.4): checked before they are
/// saved — here, for the player's immediate feedback, and by the database
/// itself (`public.display_name_problem`, latest in migration
/// `…_names_privacy.sql`), which is the actual enforcement. A test keeps
/// the two in step (`test/account/display_name_test.dart`). The database
/// also keeps names unique, ignoring case and look-alike letters
/// (`fold_display_name`): a name already held is [DisplayNameTaken].
///
/// **Provisional rules** (Phase 2 commit 9, `doc/decisions.md`).
library;

/// Longest name (the `profiles` check, the input's `maxLength`).
const maxDisplayNameLength = 30;

/// Characters a name may use: **Latin letters only** (owner, plan v3.9:
/// "Latin letters only for names at launch"; Greek and Cyrillic were
/// allowed until Phase 6a, names already saved are kept) that the bundled
/// Inter font draws (no font is fetched at runtime, a missing glyph would
/// show as a box) — Basic Latin, Latin-1, Latin Extended-A, Vietnamese —
/// digits, space and `. _ ' -`. The same text, character for character, is
/// the database's regular expression.
const displayNameCharClass = r"[A-Za-z0-9À-ÖØ-öø-ňŊ-ſẠ-ỹ ._'-]";

/// Refused anywhere in the name once separators are removed: long enough
/// not to hide inside ordinary names. Lowercase.
const blockedWords = [
  'nigger',
  'nigga',
  'faggot',
  'retard',
  'whore',
  'salope',
  'connard',
  'connasse',
  'encule',
  'enculé',
  'batard',
  'bâtard',
  'hitler',
];

/// Refused at the start of any word of the name (`fuck`, `fucker`, but not
/// `Mitsuko`). Lowercase.
const blockedWordStarts = ['fuck', 'shit', 'cunt', 'bitch', 'slut', 'pute'];

/// The database refused a name (its own check, the same rule): the
/// profile repository throws it so the screen can say why.
class DisplayNameRefused implements Exception {
  const DisplayNameRefused();

  @override
  String toString() => 'DisplayNameRefused';
}

/// Another player holds the name, or one that reads the same (case,
/// accents, look-alike letters: the database's `fold_display_name`).
class DisplayNameTaken implements Exception {
  const DisplayNameTaken();

  @override
  String toString() => 'DisplayNameTaken';
}

enum DisplayNameProblem {
  empty,
  tooLong,

  /// Leading, trailing or doubled spaces.
  spaces,

  /// A character outside [displayNameCharClass].
  charset,

  /// Only separators: no letter or digit.
  noLetter,

  /// A blocked word.
  blocked,
}

final _allowed = RegExp('^$displayNameCharClass+\$');
final _letterOrDigit = RegExp(r'[^ ._\x27-]');
final _separators = RegExp(r"[ ._'-]+");

/// The first problem with [name] as typed (not trimmed: the caller trims
/// what the player typed before calling), or `null` if it can be saved.
DisplayNameProblem? displayNameProblem(String name) {
  if (name.isEmpty) return DisplayNameProblem.empty;
  if (name.length > maxDisplayNameLength) return DisplayNameProblem.tooLong;
  if (name.trim() != name || name.contains('  ')) {
    return DisplayNameProblem.spaces;
  }
  if (!_allowed.hasMatch(name)) return DisplayNameProblem.charset;
  if (!_letterOrDigit.hasMatch(name)) return DisplayNameProblem.noLetter;
  final lower = name.toLowerCase();
  final joined = lower.replaceAll(_separators, '');
  if (blockedWords.any(joined.contains)) return DisplayNameProblem.blocked;
  final words = lower.split(_separators);
  for (final word in words) {
    if (blockedWordStarts.any(word.startsWith)) {
      return DisplayNameProblem.blocked;
    }
  }
  return null;
}
