/// Os pontos do corpo que a regra do gesto usa, num formato que não depende do modelo de pose.
///
/// O modelo (ML Kit ou MediaPipe, os dois são BlazePose com 33 pontos) entrega muito mais do que
/// isso; quem converte a saída dele para `BodyPose` é o código da câmera. Assim a regra pode ser
/// testada sem câmera e o modelo pode ser trocado sem mexer nela.
library;

/// Um ponto do corpo na imagem.
///
/// Coordenadas da imagem: `x` cresce para a direita e `y` cresce PARA BAIXO (como no ML Kit e no
/// MediaPipe). A unidade não importa (pixels ou 0–1): a regra só usa ângulos e proporções.
class BodyPoint {
  const BodyPoint(this.x, this.y, {this.confidence = 1});

  final double x;
  final double y;

  /// De 0 a 1: quanto o modelo acredita que o ponto está mesmo ali e visível
  /// (`inFrameLikelihood` no ML Kit, `visibility` no MediaPipe).
  final double confidence;
}

/// Lado do corpo da PESSOA, não da imagem: o ombro esquerdo dela aparece à direita da imagem
/// quando ela está de frente para a câmera traseira.
enum BodySide { left, right }

/// Um braço: ombro, cotovelo e pulso do mesmo lado.
class Arm {
  const Arm({required this.shoulder, required this.elbow, required this.wrist});

  final BodyPoint shoulder;
  final BodyPoint elbow;
  final BodyPoint wrist;
}

/// Uma pessoa num quadro da câmera, reduzida aos dois braços.
class BodyPose {
  const BodyPose({required this.left, required this.right});

  final Arm left;
  final Arm right;

  Arm arm(BodySide side) => side == BodySide.left ? left : right;
}
