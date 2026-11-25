/// Hands a link to the device's share sheet (plan v3.8: the friend invite
/// link). Web-specific behind it (rule 15): the Web Share API in a browser
/// that has one (`infrastructure/sharing/`).
abstract interface class LinkSharer {
  /// `true` when the share sheet took it (or the player closed it); `false`
  /// when there is none here — the caller copies the link instead.
  Future<bool> share({required String title, required Uri link});
}
