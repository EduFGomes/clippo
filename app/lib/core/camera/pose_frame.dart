import 'package:clippo/core/gesture/body_pose.dart';

/// Um quadro analisado pelo ML Kit, como chega do código nativo
/// (formato em android/.../camera/ClippoCameraSession.kt › sendPose).
class PoseFrame {
  const PoseFrame({
    required this.timestamp,
    required this.width,
    required this.height,
    required this.analysisTime,
    this.landmarks,
  });

  /// Lê o mapa do EventChannel. Os nomes das chaves precisam bater com os do Kotlin.
  factory PoseFrame.fromMap(Map<Object?, Object?> data) {
    final points = data['points'] as List<Object?>?;
    return PoseFrame(
      timestamp: Duration(microseconds: data['t'] as int),
      width: data['width'] as int,
      height: data['height'] as int,
      analysisTime: Duration(milliseconds: data['analysisMs'] as int),
      landmarks: points == null ? null : _readLandmarks(points),
    );
  }

  /// Hora em que o quadro foi filmado, no relógio do sensor (o mesmo do vídeo do buffer).
  final Duration timestamp;

  /// Tamanho da imagem já em pé, em pixels: o referencial de [landmarks].
  final int width;
  final int height;

  /// Quanto o ML Kit levou neste quadro.
  final Duration analysisTime;

  /// Os 33 pontos do BlazePose, na ordem de [PoseLandmarkIndex]; null se não achou ninguém.
  final List<BodyPoint>? landmarks;

  /// Os pontos que a regra do gesto usa; null se não há pessoa no quadro.
  BodyPose? get bodyPose {
    final p = landmarks;
    if (p == null) return null;
    Arm arm(int shoulder, int elbow, int wrist) => Arm(shoulder: p[shoulder], elbow: p[elbow], wrist: p[wrist]);
    return BodyPose(
      left: arm(PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftElbow, PoseLandmarkIndex.leftWrist),
      right: arm(PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightElbow, PoseLandmarkIndex.rightWrist),
      nose: p[PoseLandmarkIndex.nose],
    );
  }

  static List<BodyPoint> _readLandmarks(List<Object?> flat) {
    const n = PoseLandmarkIndex.valuesPerPoint;
    if (flat.length != PoseLandmarkIndex.count * n) {
      throw FormatException('Esperava ${PoseLandmarkIndex.count * n} números (33 pontos × x, y, z, confiança), veio ${flat.length}.');
    }
    double at(int i) => (flat[i] as num).toDouble();
    return [
      for (var i = 0; i < flat.length; i += n) BodyPoint(at(i), at(i + 1), z: at(i + 2), confidence: at(i + 3)),
    ];
  }
}

/// Posição de cada ponto na lista do BlazePose (os mesmos números de `PoseLandmark` no ML Kit e
/// de `PoseLandmark` no MediaPipe). Só os que o app usa; a lista completa tem 33.
abstract final class PoseLandmarkIndex {
  static const int count = 33;

  /// Quantos números o Kotlin manda por ponto: x, y, z e confiança (VALUES_PER_LANDMARK lá).
  static const int valuesPerPoint = 4;

  /// A regra usa a profundidade do nariz para recusar quem está de costas.
  static const int nose = 0;
  // Orelhas: só o laboratório usa, nas pistas de frente × costas.
  static const int leftEar = 7;
  static const int rightEar = 8;

  static const int leftShoulder = 11;
  static const int rightShoulder = 12;
  static const int leftElbow = 13;
  static const int rightElbow = 14;
  static const int leftWrist = 15;
  static const int rightWrist = 16;
  // Tronco e pernas: só o laboratório usa, para desenhar o esqueleto.
  static const int leftHip = 23;
  static const int rightHip = 24;
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
}
