import 'dart:math';

final Random _random = Random.secure();

/// Génère un identifiant UUID v4 (RFC 4122) sans dépendance externe :
/// 16 octets aléatoires cryptographiquement sûrs, avec les bits de version
/// et de variant forcés à la bonne valeur.
String generateUuidV4() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122

  String hex(int start, int end) =>
      bytes.sublist(start, end).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
