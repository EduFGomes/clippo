import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/body_pose.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';

/// Um quadro como a câmera entrega, em [ms]. Com [gesture], os braços fazem \ o /; sem, estão
/// abaixados. Com [person] = false, o ML Kit não achou ninguém.
PoseFrame _frame(int ms, {bool gesture = true, bool person = true}) => PoseFrame(
      timestamp: Duration(milliseconds: ms),
      width: 720,
      height: 1280,
      analysisTime: const Duration(milliseconds: 25),
      people: [if (person) DetectedPerson(landmarks: _points(gesture: gesture))],
    );

/// Os 33 pontos de uma pessoa em pé, de frente, com o corpo deslocado [dx] para a direita.
List<BodyPoint> _points({required bool gesture, double dx = 0}) {
  final points = List.filled(PoseLandmarkIndex.count, const BodyPoint(0, 0));
  // Ombro esquerdo da pessoa à direita da imagem (x = 400); y cresce para baixo.
  final wristY = gesture ? 500.0 : 700.0;
  points[PoseLandmarkIndex.leftShoulder] = const BodyPoint(400, 600);
  points[PoseLandmarkIndex.rightShoulder] = const BodyPoint(320, 600);
  points[PoseLandmarkIndex.leftElbow] = BodyPoint(430, gesture ? 550 : 650);
  points[PoseLandmarkIndex.rightElbow] = BodyPoint(290, gesture ? 550 : 650);
  points[PoseLandmarkIndex.leftWrist] = BodyPoint(460, wristY);
  points[PoseLandmarkIndex.rightWrist] = BodyPoint(260, wristY);
  // Nariz à frente dos ombros (que estão em z = 0): a pessoa está de frente.
  points[PoseLandmarkIndex.nose] = const BodyPoint(360, 500, z: -100);
  // Quadril embaixo dos ombros: a pessoa em pé.
  points[PoseLandmarkIndex.leftHip] = const BodyPoint(390, 800);
  points[PoseLandmarkIndex.rightHip] = const BodyPoint(330, 800);
  return [for (final p in points) BodyPoint(p.x + dx, p.y, z: p.z, confidence: p.confidence)];
}

/// Duas pessoas, como no modo várias pessoas: a da esquerda (perto, caixa grande) e a da direita
/// (longe, caixa pequena). [nearGesture] e [farGesture] dizem quem faz \ o /.
PoseFrame _two(int ms, {bool nearGesture = false, bool farGesture = false}) => PoseFrame(
      timestamp: Duration(milliseconds: ms),
      width: 720,
      height: 1280,
      analysisTime: const Duration(milliseconds: 60),
      people: [
        DetectedPerson(
          landmarks: _points(gesture: nearGesture, dx: -200),
          box: const Rect.fromLTRB(0, 400, 330, 1200),
        ),
        DetectedPerson(
          landmarks: _points(gesture: farGesture, dx: 300),
          box: const Rect.fromLTRB(550, 450, 700, 850),
        ),
      ],
    );

void main() {
  test('quadro sem pessoa vira noPerson', () {
    final observation = GesturePipeline().observe(_frame(0, person: false));
    expect(observation.verdict.check, GestureCheck.noPerson);
    expect(observation.triggered, isFalse);
  });

  test('passa o motivo da regra adiante', () {
    expect(GesturePipeline().observe(_frame(0, gesture: false)).verdict.check, GestureCheck.armNotDiagonal);
  });

  test('dispara uma vez, no quadro que completa o tempo mínimo', () {
    final pipeline = GesturePipeline();
    final triggered = [
      for (var ms = 0; ms <= 2000; ms += 100)
        if (pipeline.observe(_frame(ms, gesture: ms >= 500)).triggered) ms,
    ];
    expect(triggered, [900]);
  });

  test('perder a pessoa por muito tempo recomeça a contagem', () {
    final pipeline = GesturePipeline();
    // Gesto de 0 a 200, ninguém de 300 a 600, gesto de novo a partir de 700.
    final triggered = [
      for (var ms = 0; ms <= 2000; ms += 100)
        if (pipeline.observe(_frame(ms, person: ms < 300 || ms >= 700)).triggered) ms,
    ];
    expect(triggered, [1100]);
  });

  test('watch entrega uma observação por quadro e deixa os erros passarem', () async {
    final frames = StreamController<PoseFrame>();
    final observations = <GestureObservation>[];
    final errors = <Object>[];
    final done = Completer<void>();
    GesturePipeline().watch(frames.stream).listen(observations.add, onError: errors.add, onDone: done.complete);

    for (var ms = 0; ms <= 500; ms += 100) {
      frames.add(_frame(ms));
    }
    frames.addError(StateError('câmera caiu'));
    await frames.close();
    await done.future;

    expect(observations, hasLength(6));
    expect(observations.where((o) => o.triggered).map((o) => o.frame.timestamp), [const Duration(milliseconds: 400)]);
    expect(errors.single, isA<StateError>());
  });

  test('reset deixa disparar de novo logo em seguida', () {
    final pipeline = GesturePipeline();
    for (var ms = 0; ms <= 400; ms += 100) {
      pipeline.observe(_frame(ms));
    }
    pipeline.reset();
    final triggered = [
      for (var ms = 1000; ms <= 1400; ms += 100)
        if (pipeline.observe(_frame(ms)).triggered) ms,
    ];
    expect(triggered, [1400]);
  });

  group('várias pessoas', () {
    test('o gesto de quem está longe dispara, e o foco vai para ela', () {
      final pipeline = GesturePipeline();
      final observations = [
        for (var ms = 0; ms <= 1000; ms += 100) pipeline.observe(_two(ms, farGesture: ms >= 300)),
      ];
      final fired = observations.where((o) => o.triggered).toList();
      expect(fired.map((o) => o.frame.timestamp), [const Duration(milliseconds: 700)]);
      expect(fired.single.focus!.id, observations.first.people[1].id);
      expect(fired.single.people.map((p) => p.verdict.isGesture), [false, true]);
    });

    test('sem gesto, o foco é a maior pessoa (a mais perto)', () {
      final observation = GesturePipeline().observe(_two(0));
      expect(observation.focus, same(observation.people.first));
      expect(observation.verdict.check, GestureCheck.armNotDiagonal);
    });

    test('pessoa achada pelo detector, mas sem pontos, não dispara', () {
      final pipeline = GesturePipeline();
      final observations = [
        for (var ms = 0; ms <= 1000; ms += 100)
          pipeline.observe(PoseFrame(
            timestamp: Duration(milliseconds: ms),
            width: 720,
            height: 1280,
            analysisTime: Duration.zero,
            people: const [DetectedPerson(box: Rect.fromLTRB(10, 10, 60, 160))],
          )),
      ];
      expect(observations.any((o) => o.triggered), isFalse);
      expect(observations.last.verdict.check, GestureCheck.lowConfidence);
    });
  });
}
