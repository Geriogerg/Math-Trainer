import '../../core/sharing/link_sharer.dart';

/// Outside the browser: no share sheet yet (Phase 8 brings the native
/// one), so the link is copied.
LinkSharer createLinkSharer() => const _NoLinkSharer();

class _NoLinkSharer implements LinkSharer {
  const _NoLinkSharer();

  @override
  Future<bool> share({required String title, required Uri link}) async => false;
}
