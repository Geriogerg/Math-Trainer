import 'package:material_ui/material_ui.dart';

import 'package:math_core/models/exercise_type.dart';

/// The operator icon family (Phase 5 commit 3, `doc/plan.md` section 6.2):
/// + − × ÷ x² √ % ∫ drawn as one family — same stroke, round caps, the same
/// box — in the accent colour. Used on the type chips, the Profile's rows
/// and the leaderboard's boards; the favicon and the web app icons are
/// rendered from the same painter (`tool/icons/render_web_icons_test.dart`).
///
/// Decorative next to a label: excluded from semantics (the label says
/// the operation).
class OperatorIcon extends StatelessWidget {
  const OperatorIcon(this.type, {super.key, this.size = 18, this.color});

  final ExerciseType type;
  final double size;

  /// Defaults to the accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: OperatorIconPainter(
            type,
            color: color ?? Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Draws one operator in a square, on a unit grid scaled to the canvas.
class OperatorIconPainter extends CustomPainter {
  OperatorIconPainter(this.type, {required this.color});

  final ExerciseType type;
  final Color color;

  /// Stroke width as a share of the side: one weight for the family.
  static const strokeRatio = 0.11;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeRatio
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke);

    switch (type) {
      case ExerciseType.addition:
        line(0.5, 0.2, 0.5, 0.8);
        line(0.2, 0.5, 0.8, 0.5);
      case ExerciseType.subtraction:
        line(0.2, 0.5, 0.8, 0.5);
      case ExerciseType.multiplication:
        line(0.27, 0.27, 0.73, 0.73);
        line(0.73, 0.27, 0.27, 0.73);
      case ExerciseType.division:
        line(0.2, 0.5, 0.8, 0.5);
        canvas.drawCircle(const Offset(0.5, 0.24), strokeRatio * 0.8, fill);
        canvas.drawCircle(const Offset(0.5, 0.76), strokeRatio * 0.8, fill);
      case ExerciseType.power:
        // A small x, low left; a raised 2, thinner, high right.
        line(0.14, 0.44, 0.52, 0.84);
        line(0.52, 0.44, 0.14, 0.84);
        final two = Path()
          ..moveTo(0.61, 0.24)
          ..cubicTo(0.62, 0.11, 0.87, 0.10, 0.87, 0.24)
          ..cubicTo(0.87, 0.32, 0.78, 0.36, 0.61, 0.50)
          ..lineTo(0.89, 0.50);
        canvas.drawPath(
          two,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeRatio * 0.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      case ExerciseType.squareRoot:
        // The radical with its bar (`doc/design.md`: never without it).
        final radical = Path()
          ..moveTo(0.12, 0.56)
          ..lineTo(0.25, 0.50)
          ..lineTo(0.40, 0.84)
          ..lineTo(0.58, 0.16)
          ..lineTo(0.90, 0.16);
        canvas.drawPath(radical, stroke);
      case ExerciseType.percentage:
        line(0.78, 0.2, 0.22, 0.8);
        canvas.drawCircle(const Offset(0.3, 0.3), 0.1, stroke);
        canvas.drawCircle(const Offset(0.7, 0.7), 0.1, stroke);
      case ExerciseType.integral:
        // The long s: a hook at each end of one stroke.
        final sign = Path()
          ..moveTo(0.72, 0.20)
          ..cubicTo(0.66, 0.08, 0.50, 0.10, 0.50, 0.28)
          ..lineTo(0.50, 0.72)
          ..cubicTo(0.50, 0.90, 0.34, 0.92, 0.28, 0.80);
        canvas.drawPath(sign, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OperatorIconPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
