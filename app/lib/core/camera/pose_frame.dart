import 'dart:ui' show Rect;

import 'package:clippo/core/gesture/body_pose.dart';

/// Um quadro analisado, como chega do código nativo
/// (formato em android/.../camera/ClippoCameraSession.kt › sendFrame).
class PoseFrame {
  const PoseFrame({
    required this.timestamp,
    required this.width,
    required this.height,
    required this.analysisTime,
    this.prepTime,
    this.detectTime,
    this.poseTime,
    this.detectorOnGpu,
    this.people = const [],
  });

  /// Lê o mapa do EventChannel. Os nomes das chaves precisam bater com os do Kotlin.
  factory PoseFrame.fromMap(Map<Object?, Object?> data) {
    Duration? ms(Object? value) => value == null ? null : Duration(milliseconds: value as int);
    return PoseFrame(
      timestamp: Duration(microseconds: data['t'] as int),
      width: data['width'] as int,
      height: data['height'] as int,
      analysisTime: Duration(milliseconds: data['analysisMs'] as int),
      prepTime: ms(data['prepMs']),
      detectTime: ms(data['detectMs']),
      poseTime: ms(data['poseMs']),
      detectorOnGpu: data['detectorGpu'] as bool?,
      people: [
        for (final person in data['people'] as List<Object?>) DetectedPerson._fromMap(person as Map<Object?, Object?>),
      ],
    );
  }

  /// Hora em que o quadro foi filmado, no relógio do sensor (o mesmo do vídeo do buffer).
  final Duration timestamp;

  /// Tamanho da imagem já em pé, em pixels: o referencial dos pontos e das caixas.
  final int width;
  final int height;

  /// Quanto a análise inteira levou neste quadro.
  final Duration analysisTime;

  /// Só no modo várias pessoas, cada etapa: converter a imagem, o detector de pessoas e todas as
  /// leituras de pose somadas.
  final Duration? prepTime;
  final Duration? detectTime;
  final Duration? poseTime;

  /// Só no modo várias pessoas: se o detector rodou na placa de vídeo (senão, no processador).
  final bool? detectorOnGpu;

  /// Quem foi encontrado no quadro; vazia se ninguém.
  final List<DetectedPerson> people;
}

/// Uma pessoa encontrada no quadro.
class DetectedPerson {
  const DetectedPerson({this.landmarks, this.box});

  factory DetectedPerson._fromMap(Map<Object?, Object?> data) {
    final points = data['points'] as List<Object?>?;
    final box = data['box'] as List<Object?>?;
    double at(List<Object?> list, int i) => (list[i] as num).toDouble();
    return DetectedPerson(
      landmarks: points == null ? null : _readLandmarks(points),
      box: box == null ? null : Rect.fromLTRB(at(box, 0), at(box, 1), at(box, 2), at(box, 3)),
    );
  }

  /// Os 33 pontos do BlazePose, na ordem de [PoseLandmarkIndex]. null quando o detector achou a
  /// pessoa e o ML Kit não conseguiu ler a pose dela (comum com gente pequena, longe).
  final List<BodyPoint>? landmarks;

  /// A caixa do detector de pessoas, em pixels da imagem. Só no modo várias pessoas.
  final Rect? box;

  /// Onde a pessoa está: a caixa do detector ou, sem ela, o retângulo em volta dos pontos.
  Rect? get bounds {
    if (box != null) return box;
    final points = landmarks?.where((p) => p.confidence > 0);
    if (points == null || points.isEmpty) return null;
    var bounds = Rect.fromLTRB(points.first.x, points.first.y, points.first.x, points.first.y);
    for (final p in points) {
      bounds = bounds.expandToInclude(Rect.fromLTRB(p.x, p.y, p.x, p.y));
    }
    return bounds;
  }

  /// Os pontos que a regra do gesto usa; null se não há pontos.
  BodyPose? get bodyPose {
    final p = landmarks;
    if (p == null) return null;
    Arm arm(int shoulder, int elbow, int wrist) => Arm(shoulder: p[shoulder], elbow: p[elbow], wrist: p[wrist]);
    return BodyPose(
      left: arm(PoseLandmarkIndex.leftShoulder, PoseLandmarkIndex.leftElbow, PoseLandmarkIndex.leftWrist),
      right: arm(PoseLandmarkIndex.rightShoulder, PoseLandmarkIndex.rightElbow, PoseLandmarkIndex.rightWrist),
      nose: p[PoseLandmarkIndex.nose],
      leftHip: p[PoseLandmarkIndex.leftHip],
      rightHip: p[PoseLandmarkIndex.rightHip],
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
  // Quadril: a regra usa para achar o "para cima" do corpo.
  static const int leftHip = 23;
  static const int rightHip = 24;
  // Pernas: só o laboratório usa, para desenhar o esqueleto.
  static const int leftKnee = 25;
  static const int rightKnee = 26;
  static const int leftAnkle = 27;
  static const int rightAnkle = 28;
}
