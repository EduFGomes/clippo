import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';

/// Câmera simulada: [permission] define a permissão inicial e [saves] registra os cortes pedidos.
class _FakeCamera extends ClippoCamera {
  _FakeCamera({this.permission = true, this.failSave = false, this.withSound = true});

  final bool permission;
  final bool failSave;
  final bool withSound;
  final List<Duration> saves = [];
  final List<Duration> savedLengths = [];
  final List<String> deletedClips = [];
  final List<String> copiedToGallery = [];
  bool lastFullHd = false;
  bool lastRecordAudio = true;
  ({bool sound, bool flash, bool vibration})? lastSignal;
  int signals = 0;
  bool stopped = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<bool> hasMicrophonePermission() async => withSound;

  @override
  Future<bool> requestMicrophonePermission() async => true;

  @override
  Future<bool> start({bool multiPerson = false, bool fullHd = false, bool recordAudio = true}) async {
    lastFullHd = fullHd;
    lastRecordAudio = recordAudio;
    return recordAudio && withSound;
  }

  @override
  Future<void> stop() async => stopped = true;

  @override
  Future<SavedClip> saveHighlight({required Duration until, Duration length = HighlightLength.standard}) async {
    saves.add(until);
    savedLengths.add(length);
    if (failSave) throw const CameraFailure('Não foi possível salvar o lance.');
    return SavedClip(path: '/highlights/1.mp4', duration: length);
  }

  @override
  Future<void> signalSaved({bool sound = true, bool flash = true, bool vibration = false}) async {
    signals++;
    lastSignal = (sound: sound, flash: flash, vibration: vibration);
  }

  CaptureSettings settings = const CaptureSettings();

  @override
  Future<CaptureSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(CaptureSettings newSettings) async {
    settings = newSettings;
  }

  @override
  Future<void> deleteHighlight(SavedClip clip) async {
    deletedClips.add(clip.path);
  }

  @override
  Future<void> copyToGallery(SavedClip clip) async {
    copiedToGallery.add(clip.path);
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
    SessionsRepository? sessions,
    VoidCallback? onSaved,
    ValueChanged<Session>? onSessionCreated,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ClippoApp(
      home: CaptureScreen(
        camera: camera,
        pipeline: pipeline ?? _FakePipeline(),
        preview: _preview,
        sessions: sessions,
        onSaved: onSaved,
        onSessionCreated: onSessionCreated,
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

  testWidgets('preparar minimalista: só botões de voltar, configurações e gravar', (tester) async {
    await open(tester, camera: _FakeCamera());
    expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
    expect(find.bySemanticsLabel('Configurações da gravação'), findsOneWidget);
    expect(find.bySemanticsLabel('Iniciar gravação'), findsOneWidget);
    expect(find.text('Apoie o celular e enquadre o campo'), findsNothing);
    expect(find.text('Gravar com'), findsNothing);
    expect(find.text(r'Iniciar detecção de gesto \ o /'), findsNothing);
  });

  testWidgets('menu de configurações: altera tempo, resolução, microfone, som, flash e vibração', (tester) async {
    final camera = _FakeCamera();
    final pipeline = _FakePipeline();
    await open(tester, camera: camera, pipeline: pipeline);

    await tester.tap(find.bySemanticsLabel('Configurações da gravação'));
    await tester.pumpAndSettle();

    expect(find.text('Configurações da gravação'), findsOneWidget);
    expect(find.text('Tempo do highlight'), findsOneWidget);
    expect(find.text('Resolução da imagem'), findsOneWidget);

    await tester.tap(find.text('45s'));
    await tester.pump();

    await tester.tap(find.text('1080p (Full HD)'));
    await tester.pump();
    expect(camera.lastFullHd, isTrue);

    // Liga a vibração (4º Switch: Microfone, Som, Flash, Vibração).
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(4));
    await tester.tap(switches.at(3));
    await tester.pump();

    // Fecha o menu e inicia a gravação.
    await tester.tapAt(const Offset(200, 50));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 10));
    pipeline.frame(const Duration(seconds: 60), triggered: true);
    await tester.pump();

    expect(camera.savedLengths, [const Duration(seconds: 45)]);
    expect(camera.lastSignal?.vibration, isTrue);
    expect(camera.settings.length, const Duration(seconds: 45));
    expect(camera.settings.resolution, VideoResolution.fhd1080);
    expect(camera.settings.vibrationOnSave, isTrue);
    expect(find.text(r'últimos 45s · gesto \ o / detectado'), findsOneWidget);
    await tester.pump(ClippoMotion.savedBanner);
  });

  testWidgets('gravando: tela preta, e um toque mostra os controles por um tempo', (tester) async {
    await open(tester, camera: _FakeCamera());
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
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

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 10));
    pipeline.frame(const Duration(seconds: 50), triggered: true);
    await tester.pump();
    expect(camera.saves, [const Duration(seconds: 50)]);
    expect(camera.signals, 1);
    expect(camera.copiedToGallery, ['/highlights/1.mp4']);
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
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
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
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
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
    expect(find.bySemanticsLabel('Iniciar gravação'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
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

  testWidgets('confirmação: valida o nome e permite escolher sessão aberta ou fechada', (tester) async {
    var saved = false;
    Session? createdSession;
    final camera = _FakeCamera();
    await open(
      tester,
      camera: camera,
      onSaved: () => saved = true,
      onSessionCreated: (s) => createdSession = s,
    );
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    // Limpa o nome da sessão e tenta salvar: mostra erro e não salva.
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.ensureVisible(find.text('Salvar sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(find.text('Dê um nome para a sessão.'), findsOneWidget);
    expect(saved, isFalse);

    // Escolhe "Sessão fechada", preenche um nome válido e salva.
    await tester.ensureVisible(find.text('Sessão fechada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessão fechada'));
    await tester.pump();
    expect(
      find.text('Quem usar o código ou link pede sua permissão para entrar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pelada de quarta');
    await tester.pump();
    expect(find.text('Dê um nome para a sessão.'), findsNothing);
    await tester.ensureVisible(find.text('Salvar sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    expect(saved, isTrue);
    expect(createdSession?.name, 'Pelada de quarta');
    expect(createdSession?.isClosed, isTrue);
  });

  testWidgets('confirmação: voltar à câmera preserva highlights e reabre câmera', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
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
    expect(find.bySemanticsLabel('Iniciar gravação'), findsOneWidget);
  });

  testWidgets('confirmação: descartar pede confirmação, limpa highlights e volta a preparar', (tester) async {
    final camera = _FakeCamera();
    final pipeline = _FakePipeline();
    await open(tester, camera: camera, pipeline: pipeline);
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 15), triggered: true);
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
    expect(camera.deletedClips, ['/highlights/1.mp4']);
    expect(find.bySemanticsLabel('Iniciar gravação'), findsOneWidget);
  });

  testWidgets('sem microfone, avisa uma vez que os highlights saem sem som (R17)', (tester) async {
    final camera = _FakeCamera(withSound: false);
    await open(tester, camera: camera);
    expect(find.text('Sem microfone · os highlights saem sem som'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Voltar à câmera'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Sem microfone · os highlights saem sem som'), findsNothing);
  });

  testWidgets('confirmação: adicionar amigo aos participantes', (tester) async {
    final camera = _FakeCamera();
    await open(tester, camera: camera);
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
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

  testWidgets('confirmação: envia sessão e lances pelo SessionsRepository e mantém id no reenvio (D15)', (tester) async {
    final calls = <Map<String, dynamic>>[];
    var shouldFail = true;
    final repo = SessionsRepository(
      callFunction: (name, payload) async {
        expect(name, 'saveSession');
        calls.add(payload);
        if (shouldFail) {
          throw const SessionsFailure('Sem internet. Suas sessões aparecem assim que você conectar.');
        }
        return {'sessionId': payload['sessionId'], 'videoPaths': <String, String>{}, 'created': true};
      },
    );
    final camera = _FakeCamera();
    final pipeline = _FakePipeline();
    Session? created;
    await open(
      tester,
      camera: camera,
      pipeline: pipeline,
      sessions: repo,
      onSessionCreated: (s) => created = s,
    );

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 5));
    pipeline.frame(const Duration(seconds: 25), triggered: true);
    await tester.pump();

    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    // Seleciona o amigo Rafa na confirmação da sessão.
    await tester.ensureVisible(find.text('+ adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ adicionar'));
    await tester.pump();
    await tester.tap(find.text('+ Rafa'));
    await tester.pump();

    // Primeira tentativa falha: mostra o erro no rodapé e não sai da tela.
    await tester.ensureVisible(find.text('Salvar sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    expect(find.text('Sem internet. Suas sessões aparecem assim que você conectar.'), findsOneWidget);
    expect(created, isNull);
    expect(calls, hasLength(1));

    // Segunda tentativa passa com o MESMO sessionId (idempotência, R13).
    shouldFail = false;
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    expect(calls, hasLength(2));
    expect(calls[1]['sessionId'], calls[0]['sessionId']);
    expect(calls[1]['participantIds'], ['rafa']);
    final sentHighlights = calls[1]['highlights'] as List<dynamic>;
    expect(sentHighlights, hasLength(1));
    expect((sentHighlights.first as Map<String, dynamic>)['offsetSeconds'], 20);
    expect(created?.id, calls[0]['sessionId']);
    expect(created?.highlightCount, 1);
  });

  testWidgets('preparar e confirmação não cortam com fonte a 130 %', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(tester, camera: _FakeCamera());
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
