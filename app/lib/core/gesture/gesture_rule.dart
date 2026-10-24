/// A regra geométrica do gesto \ o / sobre UM quadro (produto.md › O gesto, regra R3).
///
/// Decide só "este quadro mostra o gesto?". Quanto tempo o gesto precisa durar e quanto esperar
/// entre um disparo e outro (R4) ficam numa etapa seguinte, que olha uma sequência de quadros.
library;

import 'dart:math' as math;

import 'body_pose.dart';

/// Os limites da regra, juntos num lugar para serem calibrados.
///
/// 🟡 Valores iniciais, ainda não medidos em quadra: a calibração a 2, 4, 6 e 8 m vai ajustá-los.
/// Ângulos em graus.
class GestureThresholds {
  const GestureThresholds({
    this.minConfidence = 0.5,
    this.minShoulderSpan = 0.5,
    this.minArmAngle = 10,
    this.maxArmAngle = 75,
    this.minElbowAngle = 130,
    this.maxNoseDepth = -0.5,
  });

  /// Confiança mínima de cada um dos 6 pontos (ombros, cotovelos e pulsos).
  final double minConfidence;

  /// Distância entre os ombros, medida em "braços" (a média da distância ombro → cotovelo).
  /// De frente para a câmera dá por volta de 1,2; de lado, perto de 0. Abaixo disto a pessoa
  /// não está de frente e não dá para saber qual braço está para fora.
  final double minShoulderSpan;

  /// Faixa de inclinação do braço (linha ombro → pulso), medida a partir da vertical para cima:
  /// 0° é o braço reto para cima, 90° é o braço na horizontal, para fora.
  /// Abaixo do mínimo, os braços estão retos para cima e não em diagonal; acima do máximo, quase
  /// na horizontal (ou para baixo).
  /// O mínimo era 15° e baixou para 10° depois do teste em vídeo de 24/10/2026: braços retos
  /// para cima mediram de −4° a 5°, e Ys fechados de verdade, de 13° a 20°.
  final double minArmAngle;
  final double maxArmAngle;

  /// Ângulo no cotovelo: 180° é o braço esticado. Abaixo disto o braço está dobrado, como na pose
  /// de "mostrar o muque", que também deixa os pulsos acima dos ombros.
  final double minElbowAngle;

  /// Até onde o nariz pode estar em relação aos ombros, em "distâncias entre ombros" (ver
  /// [PoseMeasurement.noseDepth]). Negativo = nariz mais perto da câmera que os ombros.
  /// No teste em vídeo de 24/10/2026, de frente deu de −1,5 a −2,1 e de costas de +1,4 a +2,0;
  /// −0,5 deixa folga dos dois lados. Acima disto, a pessoa está de costas.
  final double maxNoseDepth;

  /// Uma cópia com alguns valores trocados (o laboratório ajusta um limite por vez).
  GestureThresholds copyWith({
    double? minConfidence,
    double? minShoulderSpan,
    double? minArmAngle,
    double? maxArmAngle,
    double? minElbowAngle,
    double? maxNoseDepth,
  }) =>
      GestureThresholds(
        minConfidence: minConfidence ?? this.minConfidence,
        minShoulderSpan: minShoulderSpan ?? this.minShoulderSpan,
        minArmAngle: minArmAngle ?? this.minArmAngle,
        maxArmAngle: maxArmAngle ?? this.maxArmAngle,
        minElbowAngle: minElbowAngle ?? this.minElbowAngle,
        maxNoseDepth: maxNoseDepth ?? this.maxNoseDepth,
      );
}

/// O que a regra concluiu sobre um quadro. Fora `matched`, diz o PRIMEIRO motivo de recusa,
/// para a tela de laboratório mostrar por que o gesto não passou.
enum GestureCheck {
  matched,

  /// O modelo não achou ninguém no quadro. A regra nunca devolve este: quem devolve é o
  /// GesturePipeline, quando o quadro chega sem pose.
  noPerson,

  /// Algum dos 6 pontos tem confiança baixa (fora do quadro, encoberto, longe demais).
  lowConfidence,

  /// Os ombros estão quase sobrepostos: a pessoa está de lado.
  notFacingCamera,

  /// O nariz está atrás dos ombros: a pessoa está de costas. O gesto é feito "olhando para a
  /// câmera" (produto.md › O gesto), justamente para não disparar em comemorações quaisquer.
  facingAway,

  /// O pulso passou para o outro lado do corpo: braços em "X" (descartado em produto.md).
  armCrossed,

  /// O braço não está na diagonal para cima e para fora (abaixado, reto para cima ou horizontal).
  armNotDiagonal,

  /// O braço está dobrado no cotovelo.
  armBent,
}

class GestureVerdict {
  const GestureVerdict(this.check, {this.side});

  final GestureCheck check;

  /// Qual braço falhou, nas recusas que dizem respeito a um braço só.
  final BodySide? side;

  bool get isGesture => check == GestureCheck.matched;
}

/// As medidas de um braço que a regra compara com os limites.
class ArmMeasurement {
  const ArmMeasurement({required this.armAngle, required this.elbowAngle, required this.crossed});

  /// Inclinação da linha ombro → pulso a partir da vertical, em graus (ver
  /// [GestureThresholds.minArmAngle]): 0° reto para cima, 90° na horizontal para fora,
  /// negativo para dentro, acima de 90° abaixo do ombro.
  final double armAngle;

  /// Ângulo no cotovelo, em graus: 180° é o braço esticado.
  final double elbowAngle;

  /// O pulso passou para o outro lado do corpo.
  final bool crossed;
}

/// Todas as medidas de uma pose, calculadas mesmo quando ela não passa na regra: é o que o
/// laboratório mostra para entender POR QUE um gesto não passou.
class PoseMeasurement {
  const PoseMeasurement({required this.shoulderSpan, required this.left, required this.right, this.noseDepth});

  /// Distância entre os ombros, em "braços" (ver [GestureThresholds.minShoulderSpan]).
  final double shoulderSpan;

  final ArmMeasurement left;
  final ArmMeasurement right;

  /// Profundidade do nariz menos a média da dos ombros, dividida pela distância entre os ombros
  /// na imagem (para valer igual de perto ou de longe). Negativo = nariz à frente dos ombros
  /// (de frente para a câmera); positivo = atrás (de costas). Null se a pose não tem nariz.
  final double? noseDepth;

  ArmMeasurement arm(BodySide side) => side == BodySide.left ? left : right;
}

class GestureRule {
  const GestureRule([this.thresholds = const GestureThresholds()]);

  final GestureThresholds thresholds;

  GestureVerdict evaluate(BodyPose pose) {
    final points = [
      for (final side in BodySide.values) ...[pose.arm(side).shoulder, pose.arm(side).elbow, pose.arm(side).wrist],
    ];
    if (points.any((p) => p.confidence < thresholds.minConfidence)) {
      return const GestureVerdict(GestureCheck.lowConfidence);
    }

    final measurement = measure(pose);
    if (measurement.shoulderSpan < thresholds.minShoulderSpan) {
      return const GestureVerdict(GestureCheck.notFacingCamera);
    }
    // Depois de "de lado": de lado, a profundidade do nariz fica instável (os ombros quase se
    // sobrepõem e a divisão pela distância entre eles estoura).
    final noseDepth = measurement.noseDepth;
    if (noseDepth != null && noseDepth > thresholds.maxNoseDepth) {
      return const GestureVerdict(GestureCheck.facingAway);
    }

    for (final side in BodySide.values) {
      final check = _checkArm(measurement.arm(side));
      if (check != GestureCheck.matched) return GestureVerdict(check, side: side);
    }
    return const GestureVerdict(GestureCheck.matched);
  }

  GestureCheck _checkArm(ArmMeasurement arm) {
    if (arm.crossed) return GestureCheck.armCrossed;
    if (arm.armAngle < thresholds.minArmAngle || arm.armAngle > thresholds.maxArmAngle) {
      return GestureCheck.armNotDiagonal;
    }
    if (arm.elbowAngle < thresholds.minElbowAngle) return GestureCheck.armBent;
    return GestureCheck.matched;
  }

  /// A geometria da pose, sem comparar com nenhum limite. [evaluate] decide a partir daqui.
  PoseMeasurement measure(BodyPose pose) {
    // Comparar com o tamanho do próprio corpo, e não com pixels, faz a regra valer igual
    // com a pessoa a 2 m ou a 8 m da câmera.
    final upperArm = (_distance(pose.left.shoulder, pose.left.elbow) + _distance(pose.right.shoulder, pose.right.elbow)) / 2;
    final shoulderDistance = _distance(pose.left.shoulder, pose.right.shoulder);
    final shoulderSpan = upperArm == 0 ? 0.0 : shoulderDistance / upperArm;

    final nose = pose.nose;
    final shouldersZ = (pose.left.shoulder.z + pose.right.shoulder.z) / 2;
    final noseDepth = nose == null || shoulderDistance == 0 ? null : (nose.z - shouldersZ) / shoulderDistance;

    // "Para fora" é medido a partir do meio dos ombros. Assim não importa se a imagem está
    // espelhada (câmera frontal) nem de que lado da imagem fica o braço esquerdo da pessoa.
    final centerX = (pose.left.shoulder.x + pose.right.shoulder.x) / 2;
    return PoseMeasurement(
      shoulderSpan: shoulderSpan,
      left: _measureArm(pose.left, centerX),
      right: _measureArm(pose.right, centerX),
      noseDepth: noseDepth,
    );
  }

  ArmMeasurement _measureArm(Arm arm, double centerX) {
    // +1 se este ombro está à direita do centro da imagem, -1 se está à esquerda.
    final outwardSign = (arm.shoulder.x - centerX).sign;

    // Quanto o pulso foi para fora e para cima a partir do ombro. O y é invertido porque na
    // imagem ele cresce para baixo.
    final outward = (arm.wrist.x - arm.shoulder.x) * outwardSign;
    final up = arm.shoulder.y - arm.wrist.y;
    return ArmMeasurement(
      // atan2(para fora, para cima) dá o ângulo a partir da vertical: 0° reto para cima, 90° na
      // horizontal, negativo se o pulso foi para dentro e acima de 90° se está abaixo do ombro.
      armAngle: _degrees(math.atan2(outward, up)),
      elbowAngle: _elbowAngle(arm),
      crossed: (arm.wrist.x - centerX) * outwardSign <= 0,
    );
  }

  /// Ângulo no cotovelo entre o segmento até o ombro e o segmento até o pulso.
  double _elbowAngle(Arm arm) {
    final ax = arm.shoulder.x - arm.elbow.x, ay = arm.shoulder.y - arm.elbow.y;
    final bx = arm.wrist.x - arm.elbow.x, by = arm.wrist.y - arm.elbow.y;
    final lengths = math.sqrt(ax * ax + ay * ay) * math.sqrt(bx * bx + by * by);
    if (lengths == 0) return 0; // pontos sobrepostos: não dá para dizer que está esticado
    // clamp: arredondamentos podem passar de 1 por pouco, e acos(1,0000001) é NaN.
    final cos = ((ax * bx + ay * by) / lengths).clamp(-1.0, 1.0);
    return _degrees(math.acos(cos));
  }

  static double _distance(BodyPoint a, BodyPoint b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

  static double _degrees(double radians) => radians * 180 / math.pi;
}
