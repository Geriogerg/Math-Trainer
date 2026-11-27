/// The product's name and the line that presents it (Phase 6c commit 1,
/// plan v4.1: "Name as a single setting"): the one place to change them.
///
/// Read by the app (its title, every string that names the game, the share
/// sheet, the legal pages) and written into the web files by
/// `tool/brand/write_brand_test.dart` — the page's title and link preview
/// (`web/index.html`, between its brand markers), the web app manifest,
/// and the preview image (`web/preview.png`). `test/brand_test.dart` fails
/// while those files
/// say anything else: after a change here, run the tool (from `app/`):
///
///     flutter test tool/brand/write_brand_test.dart
///
/// "Math Trainer" until the owner confirms a name (plan sections 6.2 and 8:
/// the name and the domain are the owner's decision). The icons carry no
/// name: they come from the operator family
/// (`tool/icons/render_web_icons_test.dart`).
abstract final class Brand {
  /// The name, wherever the game is named.
  static const name = 'Math Trainer';

  /// Under the icon on a phone's home screen: short enough not to be cut
  /// (about 12 characters).
  static const shortName = 'Math Trainer';

  /// One sentence: search results, link previews, the manifest.
  static const description =
      'Competitive mental math: difficulty adapts to your answers.';
}
