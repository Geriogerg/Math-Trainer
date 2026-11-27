import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:math_trainer/presentation/strings/brand.dart';
import 'package:math_trainer/presentation/strings/strings.dart';

import 'brand_files.dart';

/// The name as a single setting (Phase 6c commit 1, plan v4.1): `Brand` is
/// the only place it is written; the web files are generated from it
/// (`tool/brand/write_brand_test.dart`). This fails when they disagree, and
/// when the app spells the name anywhere else.
void main() {
  test('web/index.html is as written from Brand', () {
    final html = File('web/index.html').readAsStringSync();
    expect(html, withBrand(html), reason: _regenerate);
    expect(html, contains(brandHead()));
    // Nothing else in the page names the product.
    final rest = html
        .replaceFirst(brandHead(), '')
        .replaceFirst(loaderTitle(), '')
        .replaceFirst(loaderLabel(), '');
    expect(rest, isNot(contains(Brand.name)), reason: 'only where written');
  });

  test('web/manifest.json says what Brand says', () {
    final manifest =
        (jsonDecode(File('web/manifest.json').readAsStringSync()) as Map);
    expect(
      (manifest['name'], manifest['short_name'], manifest['description']),
      (Brand.name, Brand.shortName, Brand.description),
      reason: _regenerate,
    );
  });

  test('web/preview.png is a 1200 × 630 PNG', () {
    final bytes = File('web/preview.png').readAsBytesSync();
    // The PNG signature, then the IHDR chunk: width and height, big-endian.
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits, reason: _regenerate);
    int at(int offset) =>
        (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
    expect((at(16), at(20)), (previewWidth, previewHeight));
  });

  test('the app names itself through Brand only', () {
    expect(strings.account.appName, Brand.name);
    final literal = RegExp('[\'"][^\'"\\n]*${RegExp.escape(Brand.name)}');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      if (file.path.replaceAll('\\', '/').endsWith('strings/brand.dart')) {
        continue;
      }
      for (final (i, line) in file.readAsLinesSync().indexed) {
        if (line.trimLeft().startsWith('//')) continue;
        if (literal.hasMatch(line)) offenders.add('${file.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty, reason: 'use Brand.name');
  });
}

const _regenerate =
    'run `flutter test tool/brand/write_brand_test.dart` from app/ after '
    'changing Brand';
