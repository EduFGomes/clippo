import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Ícones outline dos controles, desenhados na grade de 24 (mesmos traços dos SVGs de assets/icons/).
/// Use dentro dos componentes; telas não desenham ícones direto.
enum ClippoIconShape { chevronLeft, chevronDown, eye, eyeOff, check }

class ClippoIcon extends StatelessWidget {
  const ClippoIcon(
    this.shape, {
    super.key,
    required this.size,
    required this.color,
    this.stroke = ClippoSize.iconStroke,
  });

  final ClippoIconShape shape;
  final double size;
  final Color color;

  /// Traço na grade de 24 (escala junto com o ícone).
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _ClippoIconPainter(shape, color, stroke),
      ),
    );
  }
}

class _ClippoIconPainter extends CustomPainter {
  _ClippoIconPainter(this.shape, this.color, this.stroke);

  final ClippoIconShape shape;
  final Color color;
  final double stroke;

  static const double _grid = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _grid);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case ClippoIconShape.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(14.5, 5.5)
            ..lineTo(8, 12)
            ..lineTo(14.5, 18.5),
          paint,
        );
      case ClippoIconShape.chevronDown:
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 9.5)
            ..lineTo(12, 16)
            ..lineTo(18.5, 9.5),
          paint,
        );
      case ClippoIconShape.check:
        canvas.drawPath(
          Path()
            ..moveTo(4, 12.5)
            ..lineTo(9.5, 18)
            ..lineTo(20, 6.5),
          paint,
        );
      case ClippoIconShape.eye:
        _eye(canvas, paint);
      case ClippoIconShape.eyeOff:
        _eye(canvas, paint);
        canvas.drawLine(const Offset(3, 3), const Offset(21, 21), paint);
    }
  }

  void _eye(Canvas canvas, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(2, 12)
        ..cubicTo(2, 12, 5, 5, 12, 5)
        ..cubicTo(19, 5, 22, 12, 22, 12)
        ..cubicTo(22, 12, 19, 19, 12, 19)
        ..cubicTo(5, 19, 2, 12, 2, 12)
        ..close(),
      paint,
    );
    canvas.drawCircle(const Offset(12, 12), 3, paint);
  }

  @override
  bool shouldRepaint(_ClippoIconPainter old) =>
      old.shape != shape || old.color != color || old.stroke != stroke;
}
