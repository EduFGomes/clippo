import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/gesture_rule.dart';

const _commands = MethodChannel('clippo/camera');
const _poses = EventChannel('clippo/camera/poses');

/// Um quadro como o Kotlin manda: 33 pontos em (100, 100), z = 0, e, nos índices dos braços, um \ o /
/// em pixels de uma imagem 720×1280 (a pessoa de frente, ombro esquerdo dela à direita da imagem).
Map<String, Object?> _frameMap({bool withPerson = true, double wristConfidence = 0.9}) {
  const n = PoseLandmarkIndex.valuesPerPoint;
  final points = Float64List(PoseLandmarkIndex.count * n);
  for (var i = 0; i < PoseLandmarkIndex.count; i++) {
    points.setAll(i * n, [100, 100, 0, 0.9]);
  }
  void put(int index, double x, double y, [double confidence = 0.9]) => points.setAll(index * n, [x, y, -20, confidence]);
  put(PoseLandmarkIndex.leftShoulder, 400, 600);
  put(PoseLandmarkIndex.rightShoulder, 320, 600);
  put(PoseLandmarkIndex.leftElbow, 430, 550);
  put(PoseLandmarkIndex.rightElbow, 290, 550);
  put(PoseLandmarkIndex.leftWrist, 460, 500, wristConfidence);
  put(PoseLandmarkIndex.rightWrist, 260, 500);
  // Nariz à frente dos ombros (z menor que os −20 deles): a pessoa está de frente.
  points.setAll(PoseLandmarkIndex.nose * n, [360, 500, -100, 0.9]);
  return {'t': 1234567, 'width': 720, 'height': 1280, 'analysisMs': 42, 'points': withPerson ? points : null};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_commands, null);
    messenger.setMockStreamHandler(_poses, null);
  });

  group('PoseFrame', () {
    test('lê o mapa do Kotlin', () {
      final frame = PoseFrame.fromMap(_frameMap());
      expect(frame.timestamp, const Duration(microseconds: 1234567));
      expect((frame.width, frame.height), (720, 1280));
      expect(frame.analysisTime, const Duration(milliseconds: 42));
      expect(frame.landmarks, hasLength(33));
    });

    test('pega os braços nos índices certos do BlazePose', () {
      final pose = PoseFrame.fromMap(_frameMap()).bodyPose!;
      expect((pose.left.shoulder.x, pose.left.wrist.x), (400, 460));
      expect((pose.right.shoulder.x, pose.right.wrist.x), (320, 260));
      expect(pose.left.wrist.confidence, closeTo(0.9, 1e-9));
      expect(pose.left.wrist.z, -20);
    });

    test('a pose convertida passa pela regra do gesto', () {
      expect(const GestureRule().evaluate(PoseFrame.fromMap(_frameMap()).bodyPose!).isGesture, isTrue);
      final lowConfidence = PoseFrame.fromMap(_frameMap(wristConfidence: 0.2)).bodyPose!;
      expect(const GestureRule().evaluate(lowConfidence).check, GestureCheck.lowConfidence);
    });

    test('sem pessoa no quadro', () {
      final frame = PoseFrame.fromMap(_frameMap(withPerson: false));
      expect(frame.landmarks, isNull);
      expect(frame.bodyPose, isNull);
    });

    test('recusa uma lista com o número errado de pontos', () {
      expect(() => PoseFrame.fromMap({..._frameMap(), 'points': Float64List(10)}), throwsFormatException);
    });
  });

  group('ClippoCamera', () {
    const camera = ClippoCamera();

    test('manda os comandos com os nomes e argumentos que o Kotlin espera', () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_commands, (call) async {
        calls.add(call);
        return call.method == 'hasPermission' || call.method == 'requestPermission' ? true : null;
      });

      expect(await camera.hasPermission(), isTrue);
      expect(await camera.requestPermission(), isTrue);
      await camera.start(accurate: true);
      await camera.stop();

      expect(calls.map((c) => c.method), ['hasPermission', 'requestPermission', 'start', 'stop']);
      expect(calls[2].arguments, {'accurate': true});
    });

    test('saveHighlight manda a hora do disparo em microssegundos e lê o trecho salvo', () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(_commands, (call) async {
        sent = call;
        return {'path': '/data/clippo/lance.mp4', 'durationMs': 30000};
      });

      // Uma hora real de sensor passa de 2³¹ µs: tem que ir inteira, sem cortar.
      final clip = await camera.saveHighlight(until: const Duration(microseconds: 715396052000));

      expect(sent?.method, 'saveHighlight');
      expect(sent?.arguments, {'untilMicros': 715396052000});
      expect(clip.path, '/data/clippo/lance.mp4');
      expect(clip.duration, const Duration(seconds: 30));
    });

    test('saveHighlight sem buffer pronto vira uma mensagem da tela', () async {
      messenger.setMockMethodCallHandler(_commands, (call) async {
        throw PlatformException(code: 'not-implemented', message: 'O buffer de 30 s ainda não foi feito.');
      });
      await expectLater(
        camera.saveHighlight(until: Duration.zero),
        throwsA(isA<CameraFailure>().having((f) => f.message, 'message', contains('buffer de 30 s'))),
      );
    });

    test('copyToGallery manda o caminho do trecho e traduz o erro', () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(_commands, (call) async {
        sent = call;
        return 'content://media/external/video/media/1';
      });
      const clip = SavedClip(path: '/data/clippo/lance.mp4', duration: Duration(seconds: 30));
      await camera.copyToGallery(clip);
      expect(sent?.method, 'copyToGallery');
      expect(sent?.arguments, {'path': '/data/clippo/lance.mp4'});

      messenger.setMockMethodCallHandler(_commands, (call) async {
        throw PlatformException(code: 'gallery-failed', message: 'falhou');
      });
      await expectLater(
        camera.copyToGallery(clip),
        throwsA(isA<CameraFailure>().having((f) => f.message, 'message', contains('galeria'))),
      );
    });

    test('traduz o erro do Kotlin para uma mensagem da tela', () async {
      messenger.setMockMethodCallHandler(_commands, (call) async {
        throw PlatformException(code: 'no-permission', message: 'Sem permissão de câmera.');
      });
      await expectLater(
        camera.start(),
        throwsA(isA<CameraFailure>().having((f) => f.message, 'message', contains('precisa da câmera'))),
      );
    });

    test('entrega os quadros do EventChannel e traduz os erros do fluxo', () async {
      messenger.setMockStreamHandler(
        _poses,
        MockStreamHandler.inline(onListen: (arguments, events) {
          events.success(_frameMap());
          events.success(_frameMap(withPerson: false));
          events.error(code: 'analysis-failed', message: 'falhou');
          events.endOfStream();
        }),
      );

      final frames = <PoseFrame>[];
      final errors = <Object>[];
      // asFuture() não serve aqui: ele troca o onError e terminaria no primeiro erro.
      final done = Completer<void>();
      camera.poses.listen(frames.add, onError: errors.add, onDone: done.complete);
      await done.future;

      expect(frames.map((f) => f.bodyPose != null), [true, false]);
      expect(errors.single, isA<CameraFailure>());
    });
  });
}
