import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

/// Phase 5 commit 7: the app can be added to a phone's home screen. The
/// manifest (Chrome on Android) and the iOS tags (Safari on iPhone) name
/// files that must exist, at the sizes they declare. Runs from `app/`.
void main() {
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync())
          as Map<String, Object?>;
  final index = File('web/index.html').readAsStringSync();

  /// Width and height from a PNG's IHDR chunk.
  (int, int) pngSize(String path) {
    final bytes = File('web/$path').readAsBytesSync();
    expect(
      bytes.sublist(1, 4),
      utf8.encode('PNG'),
      reason: '$path is not a PNG',
    );
    final header = ByteData.sublistView(bytes, 16, 24);
    return (header.getUint32(0), header.getUint32(4));
  }

  test('an installable app: name, standalone, colours, scope', () {
    expect(manifest['name'], 'Math Trainer');
    expect(manifest['short_name'], isNotEmpty);
    expect(manifest['display'], 'standalone');
    expect(manifest['start_url'], './');
    expect(manifest['scope'], './');
    expect(manifest['id'], isNotEmpty);
    // doc/design.md, dark Background: the splash matches the loading screen.
    expect(manifest['background_color'], '#101528');
    expect(manifest['theme_color'], '#101528');
  });

  test('every icon exists at its declared size; any and maskable, 192 and '
      '512', () {
    final icons = (manifest['icons']! as List).cast<Map<String, Object?>>();
    final purposes = <String>{};
    for (final icon in icons) {
      final src = icon['src']! as String;
      final declared = (icon['sizes']! as String).split('x').map(int.parse);
      expect(pngSize(src), (declared.first, declared.last), reason: src);
      purposes.add('${icon['purpose']} ${declared.first}');
    }
    expect(
      purposes,
      containsAll(['any 192', 'any 512', 'maskable 192', 'maskable 512']),
    );
  });

  test('Safari on iPhone: a 180 px touch icon and the full-screen tag', () {
    final touch = RegExp(
      r'<link rel="apple-touch-icon" sizes="180x180" href="([^"]+)">',
    ).firstMatch(index);
    expect(touch, isNotNull);
    expect(pngSize(touch!.group(1)!), (180, 180));
    expect(
      index,
      contains('name="apple-mobile-web-app-capable" content="yes"'),
    );
    expect(index, contains('<link rel="manifest" href="manifest.json">'));
  });

  test('the favicon exists', () {
    expect(index, contains('href="favicon.png"'));
    expect(pngSize('favicon.png'), (64, 64));
  });
}
