import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer/presentation/kit/operator_icon.dart';
import 'package:math_trainer/presentation/strings/brand.dart';

import '../../test/brand_files.dart';
import '../../test/presentation/golden_test_utils.dart';

/// Writes the product's name into the web files (Phase 6c commit 1, plan
/// v4.1: the name as a single setting): `web/index.html`'s brand block and
/// loading screen,
/// `web/manifest.json`'s words, the email templates
/// (`supabase/templates/`), and the link-preview image
/// `web/preview.png` (1200 × 630: the operator family and the name, the
/// dark theme). Not part of the test suite (it writes files); run it after
/// changing `Brand`, from `app/`:
///
///     flutter test tool/brand/write_brand_test.dart
///
/// `test/brand_test.dart` fails until it has run.
const _background = Color(0xFF101528); // doc/design.md, dark Background
const _accent = Color(0xFF5DCAA5); // doc/design.md, dark Accent
const _text = Color(0xFFE6F1FB); // doc/design.md, dark Primary text
const _muted = Color(0xFF85B7EB); // doc/design.md, dark Secondary text

ui.Paragraph _paragraph(
  String text, {
  required double size,
  required Color color,
  required double width,
  FontWeight weight = FontWeight.w400,
}) {
  final builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: 'Inter', maxLines: 3))
        ..pushStyle(
          ui.TextStyle(
            color: color,
            fontSize: size,
            fontWeight: weight,
            fontFamily: 'Inter',
            height: 1.2,
          ),
        )
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

Future<void> _renderPreview(String path) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const w = 1200.0;
  const h = 630.0;
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = _background,
  );
  // The four basics, as on the icons, on the left.
  const box = 320.0;
  const left = 96.0;
  const top = (h - box) / 2;
  const cell = box / 2;
  const grid = [
    ExerciseType.addition,
    ExerciseType.subtraction,
    ExerciseType.multiplication,
    ExerciseType.division,
  ];
  for (final (i, type) in grid.indexed) {
    canvas.save();
    canvas.translate(left + (i % 2) * cell, top + (i ~/ 2) * cell);
    OperatorIconPainter(
      type,
      color: _accent,
    ).paint(canvas, const Size.square(cell));
    canvas.restore();
  }
  // The name and its line on the right.
  const textLeft = left + box + 80;
  const textWidth = w - textLeft - 80;
  final name = _paragraph(
    Brand.name,
    size: 84,
    color: _text,
    width: textWidth,
    weight: FontWeight.w500,
  );
  final line = _paragraph(
    Brand.description,
    size: 34,
    color: _muted,
    width: textWidth,
  );
  final textTop = (h - name.height - 28 - line.height) / 2;
  canvas.drawParagraph(name, const Offset(textLeft, 0).translate(0, textTop));
  canvas.drawParagraph(line, Offset(textLeft, textTop + name.height + 28));
  final image = await recorder.endRecording().toImage(
    previewWidth,
    previewHeight,
  );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(loadInterFontForGoldens);

  testWidgets('write the brand into the web files', (tester) async {
    await tester.runAsync(() async {
      final index = File('web/index.html');
      index.writeAsStringSync(withBrand(index.readAsStringSync()));
      final manifest = File('web/manifest.json');
      manifest.writeAsStringSync(
        withBrandManifest(manifest.readAsStringSync()),
      );
      await _renderPreview('web/preview.png');
      final templates = Directory('../supabase/templates')
        ..createSync(recursive: true);
      for (final MapEntry(key: file, value: html) in emailTemplates().entries) {
        File('${templates.path}/$file').writeAsStringSync(html);
      }
    });
  });
}
