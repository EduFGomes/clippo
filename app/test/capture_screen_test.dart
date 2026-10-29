import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';

/// Um Kotlin de mentira: [permission] decide a permissão, e cada pedido de salvar é anotado.
class _FakeCamera extends ClippoCamera {
  _FakeCamera({this.permission = true, this.failSave = false});

  final bool permission;
  final bool failSave;
  final List<Duration> saves = [];
  bool stopped = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> start({bool accurate = false, bool multiPerson = false}) async {}

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<SavedClip> saveHighlight({required Duration until}) async {
    saves.add(until);
    if (failSave) throw const CameraFailure('Não foi possível salvar o lance.');
    return const SavedClip(path: '/highlights/1.mp4', duration: Duration(seconds: 30));
  }

  @override
  Stream<PoseFrame> get poses => const Stream.empty();
}

/// Uma detecção de mentira: o teste decide quando o gesto dispara.
class _FakePipeline extends GesturePipeline {
  final _observations = StreamController<GestureObservation>.broadcast();

  void frame(Duration at, {bool triggered = false}) => _observations.add(GestureObservation(
        frame: PoseFrame(timestamp: at, width: 720, height: 1280, analysisTime: Duration.zero),
        people: const [],
        triggered: triggered,
      ));

  @override
  Stream<GestureObservation> watch(Stream<PoseFrame> frames) => _observations.stream;
}

Widget _preview(BuildContext context) => const ColoredBox(color: ClippoBrand.wine);

void main() {
  Future<void> open(WidgetTester tester, {required _FakeCamera camera, _FakePipeline? pipeline}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ClippoApp(
      home: CaptureScreen(
        camera: camera,
        pipeline: pipeline ?? _FakePipeline(),
        preview: _preview,
        friends: const [
          CaptureFriend(id: 'rafa', firstName: 'Rafa'),
          CaptureFriend(id: 'bruno', firstName: 'Bruno'),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sem permissão, explica e pede a câmera', (tester) async {
    await open(tester, camera: _FakeCamera(permission: false));
    expect(find.text('O Clippo precisa da câmera para gravar os lances.'), findsOneWidget);
    await tester.tap(find.text('Permitir câmera'));
    await tester.pump();
    expect(find.textContaining('Configurações › Apps › Clippo'), findsOneWidget);
  });

  testWidgets('preparar: dica, chips e botão de gravar', (tester) async {
    await open(tester, camera: _FakeCamera());
    expect(find.text('Apoie o celular e enquadre o campo'), findsOneWidget);
    expect(find.text('Gravar com'), findsOneWidget);
    expect(find.text('Gravar sozinho'), findsOneWidget);
    expect(find.text('Com Rafa'), findsOneWidget);
    expect(find.text(r'Iniciar detecção de gesto \ o /'), findsOneWidget);
  });

  testWidgets('escolher um amigo desmarca "Gravar sozinho", e vice-versa', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, camera: _FakeCamera());
    bool selected(String label) =>
        tester.getSemantics(find.bySemanticsLabel(label)).flagsCollection.isSelected == Tristate.isTrue;

    expect(selected('Gravar sozinho'), isTrue);
    await tester.tap(find.text('Com Rafa'));
    // A fileira rola: o segundo amigo já fica fora da tela.
    await tester.dragUntilVisible(find.text('Com Bruno'), find.byType(ListView), const Offset(-100, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Com Bruno'));
    await tester.pump();
    expect(selected('Gravar sozinho'), isFalse);
    expect(selected('Com Rafa'), isTrue);
    expect(selected('Com Bruno'), isTrue);

    await tester.dragUntilVisible(find.text('Gravar sozinho'), find.byType(ListView), const Offset(100, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gravar sozinho'));
    await tester.pump();
    expect(selected('Gravar sozinho'), isTrue);
    expect(selected('Com Rafa'), isFalse);
    semantics.dispose();
  });

  testWidgets('gravando: tela preta, e um toque mostra os controles por um tempo', (tester) async {
    await open(tester, camera: _FakeCamera());
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    expect(find.text('Apoie o celular e enquadre o campo'), findsNothing);
    expect(find.bySemanticsLabel('Detecção do gesto ligada'), findsOneWidget);
    expect(find.text('Encerrar sessão'), findsNothing);

    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    expect(find.text('Encerrar sessão'), findsOneWidget);
    expect(find.text('Cancelar gravação'), findsOneWidget);

    await tester.pump(ClippoMotion.stopControls);
    expect(find.text('Encerrar sessão'), findsNothing);
  });

  testWidgets('gesto salva os 30 s que terminam no disparo e mostra o aviso', (tester) async {
    final camera = _FakeCamera();
    final pipeline = _FakePipeline();
    await open(tester, camera: camera, pipeline: pipeline);

    // Antes de gravar, o gesto não conta.
    pipeline.frame(const Duration(seconds: 1), triggered: true);
    await tester.pump();
    expect(camera.saves, isEmpty);

    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 10));
    pipeline.frame(const Duration(seconds: 50), triggered: true);
    await tester.pump();
    expect(camera.saves, [const Duration(seconds: 50)]);
    expect(find.text('Highlight salvo'), findsOneWidget);
    expect(find.text(r'últimos 30s · gesto \ o / detectado'), findsOneWidget);

    // Some sozinho e volta ao ponto pulsante.
    await tester.pump(ClippoMotion.savedBanner);
    expect(find.text('Highlight salvo'), findsNothing);
    expect(find.bySemanticsLabel('Detecção do gesto ligada'), findsOneWidget);
  });

  testWidgets('se o buffer falha, o aviso mostra o erro', (tester) async {
    final pipeline = _FakePipeline();
    await open(tester, camera: _FakeCamera(failSave: true), pipeline: pipeline);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 5), triggered: true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Não foi possível salvar o lance.'), findsOneWidget);
    expect(find.text('Highlight salvo'), findsNothing);
    await tester.pump(ClippoMotion.savedBanner);
  });

  testWidgets('cancelar volta a preparar; encerrar desliga a câmera', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Cancelar gravação'));
    await tester.pump();
    expect(find.text('Apoie o celular e enquadre o campo'), findsOneWidget);

    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    expect(camera.stopped, isTrue);
    expect(find.text('Confirme a sessão'), findsOneWidget);
  });

  testWidgets('preparar não corta com fonte a 130 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, camera: _FakeCamera());
    expect(tester.takeException(), isNull);
  });
}
