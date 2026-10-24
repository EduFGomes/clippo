import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/gesture/body_pose.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';

// Poses montadas à mão. A pessoa está de frente para a câmera traseira: o ombro ESQUERDO dela
// aparece à direita da imagem (x = 120) e o direito à esquerda (x = 80). y cresce para baixo.
const double _shoulderY = 100;
const double _segment = 30; // ombro → cotovelo e cotovelo → pulso

/// Um braço que sai do ombro com [angle] graus a partir da vertical (0 = reto para cima,
/// 90 = horizontal para fora, negativo = para dentro). [bend] gira o antebraço em relação ao
/// braço: 0 é esticado; -90 deixa o antebraço 90° mais perto da vertical (pose de "muque").
Arm _arm(double shoulderX, {required double angle, double bend = 0, double wristConfidence = 1}) {
  final outward = shoulderX > 100 ? 1 : -1;
  BodyPoint step(BodyPoint from, double degrees, {double confidence = 1}) {
    final radians = degrees * math.pi / 180;
    return BodyPoint(
      from.x + outward * _segment * math.sin(radians),
      from.y - _segment * math.cos(radians),
      confidence: confidence,
    );
  }

  final shoulder = BodyPoint(shoulderX, _shoulderY);
  final elbow = step(shoulder, angle);
  final wrist = step(elbow, angle + bend, confidence: wristConfidence);
  return Arm(shoulder: shoulder, elbow: elbow, wrist: wrist);
}

BodyPose _pose({double left = 35, double right = 35, double leftBend = 0, double rightBend = 0}) => BodyPose(
      left: _arm(120, angle: left, bend: leftBend),
      right: _arm(80, angle: right, bend: rightBend),
    );

BodyPose _scaled(BodyPose pose, double factor) {
  BodyPoint s(BodyPoint p) => BodyPoint(p.x * factor, p.y * factor, confidence: p.confidence);
  Arm a(Arm arm) => Arm(shoulder: s(arm.shoulder), elbow: s(arm.elbow), wrist: s(arm.wrist));
  return BodyPose(left: a(pose.left), right: a(pose.right));
}

/// A mesma pose vista num espelho (câmera frontal): os lados da imagem se invertem.
BodyPose _mirrored(BodyPose pose) {
  BodyPoint m(BodyPoint p) => BodyPoint(200 - p.x, p.y, confidence: p.confidence);
  Arm a(Arm arm) => Arm(shoulder: m(arm.shoulder), elbow: m(arm.elbow), wrist: m(arm.wrist));
  return BodyPose(left: a(pose.left), right: a(pose.right));
}

void main() {
  const rule = GestureRule();

  group('aceita o \\ o /', () {
    test('braços esticados em diagonal', () => expect(rule.evaluate(_pose()).isGesture, isTrue));

    test('perto do limite de cada lado da faixa de ângulo', () {
      expect(rule.evaluate(_pose(left: 17, right: 73)).isGesture, isTrue);
    });

    test('cotovelo levemente dobrado', () {
      expect(rule.evaluate(_pose(left: 60, leftBend: -45)).isGesture, isTrue);
    });

    test('a pessoa longe (pequena na imagem) ou perto (grande)', () {
      expect(rule.evaluate(_scaled(_pose(), 0.05)).isGesture, isTrue);
      expect(rule.evaluate(_scaled(_pose(), 10)).isGesture, isTrue);
    });

    test('imagem espelhada (câmera frontal)', () {
      expect(rule.evaluate(_mirrored(_pose())).isGesture, isTrue);
    });
  });

  group('recusa', () {
    void expectRejected(BodyPose pose, GestureCheck check, [BodySide? side]) {
      final verdict = rule.evaluate(pose);
      expect(verdict.isGesture, isFalse);
      expect(verdict.check, check);
      if (side != null) expect(verdict.side, side);
    }

    test('um braço só (R3)', () => expectRejected(_pose(right: 170), GestureCheck.armNotDiagonal, BodySide.right));

    test('braços abaixados', () => expectRejected(_pose(left: 180, right: 180), GestureCheck.armNotDiagonal));

    test('braços retos para cima', () => expectRejected(_pose(left: 0, right: 0), GestureCheck.armNotDiagonal));

    test('braços na horizontal', () => expectRejected(_pose(left: 90, right: 90), GestureCheck.armNotDiagonal));

    test('logo fora da faixa de ângulo', () {
      expectRejected(_pose(left: 13), GestureCheck.armNotDiagonal, BodySide.left);
      expectRejected(_pose(right: 77), GestureCheck.armNotDiagonal, BodySide.right);
    });

    test('braços cruzados em X', () => expectRejected(_pose(left: -40, right: -40), GestureCheck.armCrossed));

    test('braço um pouco para dentro, sem cruzar', () {
      expectRejected(_pose(left: -10), GestureCheck.armNotDiagonal, BodySide.left);
    });

    test('pose de "muque" (pulsos acima dos ombros, braços dobrados)', () {
      expectRejected(_pose(left: 90, right: 90, leftBend: -90, rightBend: -90), GestureCheck.armBent);
    });

    test('cotovelo dobrado demais', () => expectRejected(_pose(left: 70, leftBend: -60), GestureCheck.armBent));

    test('um ponto com pouca confiança', () {
      final pose = BodyPose(left: _arm(120, angle: 35, wristConfidence: 0.3), right: _arm(80, angle: 35));
      expectRejected(pose, GestureCheck.lowConfidence);
    });

    test('pessoa de lado (ombros quase sobrepostos)', () {
      final pose = BodyPose(left: _arm(101, angle: 35), right: _arm(99, angle: 35));
      expectRejected(pose, GestureCheck.notFacingCamera);
    });

    test('todos os pontos no mesmo lugar', () {
      const p = BodyPoint(50, 50);
      const arm = Arm(shoulder: p, elbow: p, wrist: p);
      expectRejected(const BodyPose(left: arm, right: arm), GestureCheck.notFacingCamera);
    });
  });

  group('mede', () {
    test('o ângulo de cada braço e o cotovelo esticado', () {
      final m = rule.measure(_pose(left: 35, right: 50));
      expect(m.left.armAngle, closeTo(35, 1e-9));
      expect(m.right.armAngle, closeTo(50, 1e-9));
      expect(m.left.elbowAngle, closeTo(180, 1e-6));
      expect(m.left.crossed, isFalse);
    });

    test('o cotovelo dobrado e o ângulo da linha ombro → pulso', () {
      // Braço a 60° e antebraço a 15° (mesmo comprimento): a linha ombro → pulso fica no meio.
      final m = rule.measure(_pose(left: 60, leftBend: -45));
      expect(m.left.elbowAngle, closeTo(135, 1e-9));
      expect(m.left.armAngle, closeTo(37.5, 1e-9));
    });

    test('braço cruzado e braço abaixo do ombro', () {
      expect(rule.measure(_pose(left: -40)).left.crossed, isTrue);
      expect(rule.measure(_pose(right: 170)).right.armAngle, closeTo(170, 1e-9));
    });

    test('a distância entre os ombros em "braços"', () {
      // Ombros em x = 120 e 80 (40 de distância), braço de 30.
      expect(rule.measure(_pose()).shoulderSpan, closeTo(40 / 30, 1e-9));
      const p = BodyPoint(50, 50);
      const arm = Arm(shoulder: p, elbow: p, wrist: p);
      expect(rule.measure(const BodyPose(left: arm, right: arm)).shoulderSpan, 0);
    });

    test('mede mesmo quando a regra recusa por confiança', () {
      final pose = BodyPose(left: _arm(120, angle: 35, wristConfidence: 0.1), right: _arm(80, angle: 35));
      expect(rule.evaluate(pose).check, GestureCheck.lowConfidence);
      expect(rule.measure(pose).left.armAngle, closeTo(35, 1e-9));
    });
  });

  test('usa os limites recebidos', () {
    const strict = GestureRule(GestureThresholds(minArmAngle: 40));
    expect(strict.evaluate(_pose()).check, GestureCheck.armNotDiagonal);
    expect(strict.evaluate(_pose(left: 45, right: 45)).isGesture, isTrue);
  });
}
