import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:math_core/models/exercise_type.dart';
import 'package:math_trainer/presentation/kit/operator_icon.dart';

/// Renders the favicon and the web app icons from the operator family
/// (Phase 5 commit 3): + − × ÷ in a 2 × 2 grid, the dark theme's accent on
/// its background. Not part of the test suite (it writes files); run it
/// after changing `OperatorIconPainter`, from `app/`:
///
///     flutter test tool/icons/render_web_icons_test.dart
const _background = Color(0xFF101528); // doc/design.md, dark Background
const _accent = Color(0xFF5DCAA5); // doc/design.md, dark Accent

/// [content]: share of the side the 2 × 2 grid may use; [rounded]: corner
/// radius as a share of the side (0: full bleed, for maskable and Apple
/// icons, which the platform crops itself).
Future<void> _render(
  String path,
  int side, {
  required double content,
  required double rounded,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = side.toDouble();
  final paint = Paint()..color = _background;
  if (rounded == 0) {
    canvas.drawRect(Rect.fromLTWH(0, 0, s, s), paint);
  } else {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, s, s),
        Radius.circular(s * rounded),
      ),
      paint,
    );
  }
  final box = s * content;
  final origin = (s - box) / 2;
  final cell = box / 2;
  const grid = [
    ExerciseType.addition,
    ExerciseType.subtraction,
    ExerciseType.multiplication,
    ExerciseType.division,
  ];
  for (final (i, type) in grid.indexed) {
    canvas.save();
    canvas.translate(origin + (i % 2) * cell, origin + (i ~/ 2) * cell);
    OperatorIconPainter(type, color: _accent).paint(canvas, Size.square(cell));
    canvas.restore();
  }
  final image = await recorder.endRecording().toImage(side, side);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  testWidgets('render the web icons', (tester) async {
    await tester.runAsync(() async {
      // Browser tab: a rounded tile, the grid nearly edge to edge.
      await _render('web/favicon.png', 64, content: 0.86, rounded: 0.22);
      // Installed app ("any"): rounded tile.
      await _render(
        'web/icons/Icon-192.png',
        192,
        content: 0.72,
        rounded: 0.22,
      );
      await _render(
        'web/icons/Icon-512.png',
        512,
        content: 0.72,
        rounded: 0.22,
      );
      // Maskable: full bleed, the grid inside the 80 % safe circle.
      await _render(
        'web/icons/Icon-maskable-192.png',
        192,
        content: 0.52,
        rounded: 0,
      );
      await _render(
        'web/icons/Icon-maskable-512.png',
        512,
        content: 0.52,
        rounded: 0,
      );
      // iOS home screen (Safari): full bleed, iOS rounds the corners.
      await _render(
        'web/icons/apple-touch-icon.png',
        180,
        content: 0.62,
        rounded: 0,
      );
    });
  });
}
