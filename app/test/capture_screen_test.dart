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

/// Câmera simulada: [permission] define a permissão inicial e [saves] registra os cortes pedidos.
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

/// Detector simulado para disparar o gesto sob controle do teste.
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
  Future<void> open(
    WidgetTester tester, {
    required _FakeCamera camera,
    _FakePipeline? pipeline,
    VoidCallback? onSaved,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ClippoApp(
      home: CaptureScreen(
        camera: camera,
        pipeline: pipeline ?? _FakePipeline(),
        preview: _preview,
        onSaved: onSaved,
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

  testWidgets('cancelar pede confirmação antes de voltar a preparar; encerrar abre confirmação', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Cancelar gravação'));
    await tester.pump();
    expect(find.text('Cancelar gravação?'), findsOneWidget);

    // Desistir de cancelar mantém na gravação.
    await tester.tap(find.text('Continuar gravando'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('Detecção do gesto ligada'), findsOneWidget);

    // Confirmar cancelamento volta para preparar.
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Cancelar gravação'));
    await tester.pump();
    await tester.tap(find.text('Sim, cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Apoie o celular e enquadre o campo'), findsOneWidget);

    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();
    expect(camera.stopped, isTrue);
    expect(find.text('CONFIRME A\nSESSÃO.'), findsOneWidget);
    expect(find.text('Gravação encerrada · nenhum highlight'), findsOneWidget);
    expect(find.text('Salvar sessão'), findsOneWidget);
    expect(find.text('Descartar'), findsOneWidget);
  });

  testWidgets('confirmação: valida o nome da sessão antes de salvar', (tester) async {
    var saved = false;
    final camera = _FakeCamera();
    await open(tester, camera: camera, onSaved: () => saved = true);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    // Limpa o nome da sessão e tenta salvar: mostra erro e não salva.
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.pump();
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    expect(find.text('Informe o nome da sessão.'), findsOneWidget);
    expect(saved, isFalse);

    // Preenche um nome válido e salva.
    await tester.enterText(find.byType(TextField).first, 'Pelada de quarta');
    await tester.pump();
    expect(find.text('Informe o nome da sessão.'), findsNothing);
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('confirmação: voltar à câmera preserva highlights e reabre câmera', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Voltar à câmera'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Apoie o celular e enquadre o campo'), findsOneWidget);
  });

  testWidgets('confirmação: descartar pede confirmação, limpa highlights e volta a preparar', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    await tester.ensureVisible(find.text('Descartar'));
    await tester.pump();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Descartar sessão?'), findsOneWidget);

    await tester.tap(find.text('Sim, descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Apoie o celular e enquadre o campo'), findsOneWidget);
  });

  testWidgets('confirmação: adicionar amigo aos participantes', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Você'), findsOneWidget);
    expect(find.text('+ adicionar'), findsOneWidget);

    await tester.tap(find.text('+ adicionar'));
    await tester.pump();
    expect(find.text('+ Rafa'), findsOneWidget);

    await tester.tap(find.text('+ Rafa'));
    await tester.pump();
    expect(find.text('Rafa'), findsOneWidget);
  });

  testWidgets('preparar e confirmação não cortam com fonte a 130 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, camera: _FakeCamera());
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(r'Iniciar detecção de gesto \ o /'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
