import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/body_pose.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/dev/gesture_lab_screen.dart';
import 'package:clippo/dev/pose_skeleton_painter.dart';

/// Um quadro 720×1280 com o ombro esquerdo em (400, 600) e o cotovelo esquerdo em (430, 550).
PoseFrame _frame({double elbowConfidence = 0.9}) {
  final points = List.filled(PoseLandmarkIndex.count, const BodyPoint(100, 100, confidence: 0.9));
  points[PoseLandmarkIndex.leftShoulder] = const BodyPoint(400, 600, confidence: 0.9);
  points[PoseLandmarkIndex.leftElbow] = BodyPoint(430, 550, confidence: elbowConfidence);
  return PoseFrame(
    timestamp: Duration.zero,
    width: 720,
    height: 1280,
    analysisTime: Duration.zero,
    landmarks: points,
  );
}

PoseSkeletonPainter _painter(PoseFrame frame, GestureVerdict verdict) => PoseSkeletonPainter(
      frame: frame,
      verdict: verdict,
      minConfidence: 0.5,
      colors: ClippoColors.dark,
    );

/// Desenha numa caixa de 180×320: um quarto da imagem, na mesma proporção (e cabe na tela de\n/// teste, que tem 800×600).
Future<void> _pump(WidgetTester tester, CustomPainter painter) => tester.pumpWidget(
      Center(child: SizedBox(width: 180, height: 320, child: CustomPaint(painter: painter))),
    );

/// O `paints` confere os traços NA ORDEM: o pintor desenha primeiro os 8 ossos do tronco e das
/// pernas, depois ombro → cotovelo esquerdo. Este padrão aceita quaisquer 8 traços primeiro.
PaintPattern _afterBody() {
  final pattern = paints;
  for (var i = 0; i < 8; i++) {
    pattern.line();
  }
  return pattern;
}

void main() {
  group('esqueleto', () {
    testWidgets('escala os pontos da imagem para a tela e pinta o \\ o / em pêssego', (tester) async {
      await _pump(tester, _painter(_frame(), const GestureVerdict(GestureCheck.matched)));
      // Ombro → cotovelo esquerdo, a um quarto: (100, 150) → (107,5, 137,5).
      expect(
        find.byType(CustomPaint),
        _afterBody()..line(p1: const Offset(100, 150), p2: const Offset(107.5, 137.5), color: ClippoBrand.peach),
      );
    });

    testWidgets('pinta com a cor de erro o braço que reprovou', (tester) async {
      await _pump(tester, _painter(_frame(), const GestureVerdict(GestureCheck.armBent, side: BodySide.left)));
      expect(
        find.byType(CustomPaint),
        _afterBody()..line(p1: const Offset(100, 150), p2: const Offset(107.5, 137.5), color: ClippoColors.dark.error),
      );
    });

    testWidgets('apaga o osso com um ponto de pouca confiança', (tester) async {
      await _pump(tester, _painter(_frame(elbowConfidence: 0.2), const GestureVerdict(GestureCheck.lowConfidence)));
      expect(
        find.byType(CustomPaint),
        _afterBody()..line(p1: const Offset(100, 150), p2: const Offset(107.5, 137.5), color: ClippoBrand.captureChipBorder),
      );
    });

    testWidgets('sem pessoa, não desenha nada', (tester) async {
      final empty = PoseFrame(timestamp: Duration.zero, width: 720, height: 1280, analysisTime: Duration.zero);
      await _pump(tester, _painter(empty, const GestureVerdict(GestureCheck.noPerson)));
      expect(find.byType(CustomPaint), isNot(paints..line()));
    });
  });

  group('texto das medidas', () {
    const limits = GestureThresholds();

    test('mostra os ângulos dos dois braços, os ombros e os limites', () {
      const m = PoseMeasurement(
        shoulderSpan: 1.34,
        left: ArmMeasurement(armAngle: 34.4, elbowAngle: 167.6, crossed: false),
        right: ArmMeasurement(armAngle: 12.2, elbowAngle: 175, crossed: false),
        noseDepth: -1.83,
        bodyTilt: 89.6,
      );
      expect(
        measurementText(m, limits),
        'Esq.: braço 34° · cotovelo 168°\n'
        'Dir.: braço 12° · cotovelo 175°\n'
        'Ombros: 1,3 braços · nariz -1,8 · corpo 90°\n'
        'Limites: braço 10°–75° · cotovelo ≥ 130° · ombros ≥ 0,5 · nariz ≤ -0,5',
      );
    });

    test('braço cruzado aparece por extenso', () {
      const m = PoseMeasurement(
        shoulderSpan: 1.2,
        left: ArmMeasurement(armAngle: -40, elbowAngle: 180, crossed: true),
        right: ArmMeasurement(armAngle: 30, elbowAngle: 180, crossed: false),
      );
      expect(measurementText(m, limits), startsWith('Esq.: braço cruzado · cotovelo 180°'));
    });

    test('sem pessoa, só os limites', () {
      expect(measurementText(null, limits), startsWith('Sem medidas\nLimites:'));
    });
  });

  group('frente × costas', () {
    /// Ombros a 80 de distância; [leftOnRight] põe o ombro esquerdo à direita da imagem (de
    /// frente para a câmera traseira); [noseZ] é a profundidade do nariz (ombros em z = 0).
    PoseFrame facing({required bool leftOnRight, required double noseZ}) {
      final points = List.filled(PoseLandmarkIndex.count, const BodyPoint(0, 0, confidence: 0.9));
      points[PoseLandmarkIndex.leftShoulder] = BodyPoint(leftOnRight ? 400 : 320, 600);
      points[PoseLandmarkIndex.rightShoulder] = BodyPoint(leftOnRight ? 320 : 400, 600);
      points[PoseLandmarkIndex.nose] = BodyPoint(360, 500, z: noseZ, confidence: 0.99);
      return PoseFrame(timestamp: Duration.zero, width: 720, height: 1280, analysisTime: Duration.zero, landmarks: points);
    }

    test('de frente: ombro esquerdo à direita e nariz à frente dos ombros', () {
      expect(
        facingText(facing(leftOnRight: true, noseZ: -40)),
        'Frente × costas: ombro esq. à direita (frente?) · nariz z -0,50 · confiança nariz 0,99, orelhas 0,90/0,90',
      );
    });

    test('de costas: ombro esquerdo à esquerda e nariz atrás dos ombros', () {
      final text = facingText(facing(leftOnRight: false, noseZ: 40));
      expect(text, contains('ombro esq. à esquerda (costas?)'));
      expect(text, contains('nariz z 0,50'));
    });

    test('sem pessoa', () {
      final empty = PoseFrame(timestamp: Duration.zero, width: 720, height: 1280, analysisTime: Duration.zero);
      expect(facingText(empty), 'Frente × costas: –');
    });
  });
}
