import 'package:flutter/material.dart';

import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/body_pose.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';

/// Desenha os pontos do corpo por cima da imagem da câmera, no laboratório do gesto.
///
/// O CustomPaint precisa ter a MESMA proporção da imagem analisada (9:16 em pé): aí cada ponto
/// cai no lugar certo só escalando x e y, sem cortes nem margens para descontar.
class PoseSkeletonPainter extends CustomPainter {
  PoseSkeletonPainter({
    required this.frame,
    required this.verdict,
    required this.minConfidence,
    required this.colors,
  });

  final PoseFrame frame;
  final GestureVerdict verdict;

  /// Abaixo disto, o ponto é desenhado apagado: é o que a regra chama de "pouca confiança".
  final double minConfidence;

  /// Cores do tema (a de erro vem daqui).
  final ClippoColors colors;

  /// Os ossos do tronco e das pernas, pelos índices do BlazePose. Mãos, pés e rosto ficam de
  /// fora: a regra não usa, e encheriam a tela de traços.
  static const List<(int, int)> _body = [
    (PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.rightShoulder),
    (PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftHip),
    (PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightHip),
    (PoseLandmarkIndex.leftHip, PoseLandmarkIndex.rightHip),
    (PoseLandmarkIndex.leftHip, PoseLandmarkIndex.leftKnee),
    (PoseLandmarkIndex.leftKnee, PoseLandmarkIndex.leftAnkle),
    (PoseLandmarkIndex.rightHip, PoseLandmarkIndex.rightKnee),
    (PoseLandmarkIndex.rightKnee, PoseLandmarkIndex.rightAnkle),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = frame.landmarks;
    if (points == null) return;

    // Pixels da imagem analisada → pixels da tela.
    final sx = size.width / frame.width;
    final sy = size.height / frame.height;
    Offset at(BodyPoint p) => Offset(p.x * sx, p.y * sy);

    final line = Paint()
      ..strokeWidth = ClippoSize.meter
      ..strokeCap = StrokeCap.round;

    void bone(int a, int b, Color color) {
      final pa = points[a], pb = points[b];
      final reliable = pa.confidence >= minConfidence && pb.confidence >= minConfidence;
      line.color = reliable ? color : ClippoBrand.captureChipBorder;
      canvas.drawLine(at(pa), at(pb), line);
    }

    for (final (a, b) in _body) {
      bone(a, b, ClippoBrand.captureTextMuted);
    }
    for (final side in BodySide.values) {
      final (shoulder, elbow, wrist) = side == BodySide.left
          ? (PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftElbow, PoseLandmarkIndex.leftWrist)
          : (PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightElbow, PoseLandmarkIndex.rightWrist);
      final color = _armColor(side);
      bone(shoulder, elbow, color);
      bone(elbow, wrist, color);
    }
  }

  /// Os braços contam a história: pêssego quando é \ o /, cor de erro no braço que reprovou.
  Color _armColor(BodySide side) {
    if (verdict.isGesture) return ClippoBrand.peach;
    if (verdict.side == side) return colors.error;
    return ClippoBrand.onWine;
  }

  @override
  bool shouldRepaint(PoseSkeletonPainter old) => old.frame != frame || old.verdict != verdict || old.minConfidence != minConfidence;
}
