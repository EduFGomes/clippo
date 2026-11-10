import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_capture_chip.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';

import 'upload_queue_test.dart' show FakeUploadBackend;

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

const List<Friend> _friends = [
  Friend(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
  Friend(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima'),
];

UploadQueue _queue(FakeUploadBackend backend) => UploadQueue(
      backend: backend,
      store: MemoryUploadQueueStore(),
      deleteLocalFile: (_) async {},
      localFileExists: (_) async => true,
      retryDelays: const [],
    );

void main() {
  Future<void> open(
    WidgetTester tester, {
    required _FakeCamera camera,
    _FakePipeline? pipeline,
    UploadQueue? uploads,
    Stream<List<Friend>>? friends,
    bool noFriends = false,
    VoidCallback? onOpenFriends,
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
        uploads: uploads,
        onOpenFriends: onOpenFriends,
        onSaved: onSaved,
        onSessionCreated: onSessionCreated,
        friends: noFriends ? null : (friends ?? Stream.value(_friends)),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Salvar sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar sessão'));
    await tester.pump();
    await tester.pump();
  }

  /// Os chips "Gravar com" rolam na horizontal: traz o chip para a tela antes de tocar.
  Future<void> tapChip(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pump();
  }

  bool isSelected(WidgetTester tester, String label) =>
      tester.widget<ClippoCaptureChip>(find.widgetWithText(ClippoCaptureChip, label)).selected;

  testWidgets('sem permissão, explica e pede a câmera', (tester) async {
    await open(tester, camera: _FakeCamera(permission: false));
    expect(find.text('O Clippo precisa da câmera para gravar os lances.'), findsOneWidget);
    await tester.tap(find.text('Permitir câmera'));
    await tester.pump();
    expect(find.textContaining('Configurações › Apps › Clippo'), findsOneWidget);
  });

  testWidgets('preparar: chips Gravar com mostram os amigos reais', (tester) async {
    await open(tester, camera: _FakeCamera());
    expect(find.bySemanticsLabel('Voltar'), findsOneWidget);
    expect(find.bySemanticsLabel('Configurações da gravação'), findsOneWidget);
    expect(find.bySemanticsLabel('Iniciar gravação'), findsOneWidget);
    expect(find.text('Gravar com'), findsOneWidget);
    expect(find.text('Gravar sozinho'), findsOneWidget);
    expect(find.text('Com Rafa'), findsOneWidget);
    expect(find.text('Com Bruno'), findsOneWidget);
    expect(find.textContaining('adicione seus amigos', findRichText: true), findsNothing);
    expect(isSelected(tester, 'Gravar sozinho'), isTrue);

    // Marcar um amigo desmarca "Gravar sozinho"; dá para marcar vários.
    await tapChip(tester, 'Com Rafa');
    await tapChip(tester, 'Com Bruno');
    expect(isSelected(tester, 'Gravar sozinho'), isFalse);
    expect(isSelected(tester, 'Com Rafa'), isTrue);
    expect(isSelected(tester, 'Com Bruno'), isTrue);

    // "Gravar sozinho" limpa a escolha.
    await tapChip(tester, 'Gravar sozinho');
    expect(isSelected(tester, 'Com Rafa'), isFalse);
    expect(isSelected(tester, 'Gravar sozinho'), isTrue);
  });

  testWidgets('sem amigos: só Gravar sozinho e uma frase que leva à tela Amigos', (tester) async {
    var opened = false;
    await open(tester, camera: _FakeCamera(), noFriends: true, onOpenFriends: () => opened = true);
    expect(find.text('Gravar sozinho'), findsOneWidget);
    expect(find.textContaining('Com '), findsNothing);
    await tester.tap(find.textContaining('adicione seus amigos', findRichText: true));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('amigos chegam depois e quem deixa de ser amigo sai da escolha', (tester) async {
    final friends = StreamController<List<Friend>>();
    addTearDown(friends.close);
    await open(tester, camera: _FakeCamera(), friends: friends.stream);
    expect(find.text('Com Rafa'), findsNothing);

    friends.add(_friends);
    await tester.pump();
    await tester.pump();
    await tapChip(tester, 'Com Rafa');
    expect(isSelected(tester, 'Com Rafa'), isTrue);

    friends.add([_friends.last]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Com Rafa'), findsNothing);
    expect(isSelected(tester, 'Gravar sozinho'), isTrue);
  });

  test('acceptedFriends: só as amizades aceitas, em ordem de nome', () async {
    Friendship f(String uid, String name, FriendshipStatus status) => Friendship(
          id: 'dono_$uid',
          status: status,
          requestedBy: 'dono',
          requestedTo: uid,
          other: Friend(uid: uid, name: name, username: uid),
        );
    final result = await acceptedFriends(Stream.value([
      f('rafa', 'Rafa Costa', FriendshipStatus.accepted),
      f('caio', 'Caio Reis', FriendshipStatus.pending),
      f('alice', 'Alice Souza', FriendshipStatus.accepted),
    ])).first;
    expect(result.map((x) => x.uid), ['alice', 'rafa']);
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

  testWidgets('confirmação: valida o nome e não tem mais sessão aberta ou fechada', (tester) async {
    var saved = false;
    Session? createdSession;
    final camera = _FakeCamera();
    await open(
      tester,
      camera: camera,
      onSaved: () => saved = true,
      onSessionCreated: (s) => createdSession = s,
    );
    await finish(tester);
    expect(find.text('Sessão aberta'), findsNothing);
    expect(find.text('Sessão fechada'), findsNothing);

    // Limpa o nome da sessão e tenta salvar: mostra erro e não salva.
    await tester.enterText(find.byType(TextField).first, '   ');
    await tapSave(tester);
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(find.text('Dê um nome para a sessão.'), findsOneWidget);
    expect(saved, isFalse);

    await tester.enterText(find.byType(TextField).first, 'Pelada de quarta');
    await tester.pump();
    expect(find.text('Dê um nome para a sessão.'), findsNothing);
    await tapSave(tester);
    expect(saved, isTrue);
    expect(createdSession?.name, 'Pelada de quarta');
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

  testWidgets('salvar: amigos escolhidos vão no saveSession e o vídeo sobe para o videoPath (R13)',
      (tester) async {
    final backend = FakeUploadBackend();
    final queue = _queue(backend);
    addTearDown(queue.dispose);
    final camera = _FakeCamera();
    final pipeline = _FakePipeline();
    Session? created;
    await open(tester, camera: camera, pipeline: pipeline, uploads: queue, onSessionCreated: (s) => created = s);

    await tapChip(tester, 'Com Rafa');
    await tester.tap(find.bySemanticsLabel('Iniciar gravação'));
    await tester.pump();
    pipeline.frame(const Duration(seconds: 5));
    pipeline.frame(const Duration(seconds: 25), triggered: true);
    await tester.pump();
    await tester.pump(ClippoMotion.savedBanner);
    await tester.tapAt(const Offset(206, 400));
    await tester.pump();
    await tester.tap(find.text('Encerrar sessão'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Rafa'), findsOneWidget); // já nos participantes
    await tapSave(tester);

    expect(backend.savedSessions, hasLength(1));
    expect(created?.participantIds, ['dono', 'rafa']);
    expect(created?.highlightCount, 1);
    expect(backend.uploads, ['sessions/${created!.id}/highlights/lance-0001/video.mp4']);
    // Enviado, mas o vídeo local continua até o Firestore marcar uploaded.
    expect(camera.deletedClips, isEmpty);
    expect(queue.state.value.isPending(created!.id), isTrue);
  });

  testWidgets('salvar sem internet: a sessão fica na fila e a tela segue para a Início', (tester) async {
    final backend = FakeUploadBackend()..failSave = true;
    final queue = _queue(backend);
    addTearDown(queue.dispose);
    Session? created;
    await open(tester, camera: _FakeCamera(), uploads: queue, onSessionCreated: (s) => created = s);
    await finish(tester);
    await tapSave(tester);

    expect(created, isNotNull);
    expect(queue.state.value.unsavedSessions.single.sessionId, created!.id);
  });

  testWidgets('erro do saveSession aparece no campo certo (participantes, nome)', (tester) async {
    final backend = FakeUploadBackend()
      ..saveError = const SessionsFailure('Só dá para gravar com os seus amigos.', code: 'participantIds');
    final queue = _queue(backend);
    addTearDown(queue.dispose);
    Session? created;
    await open(tester, camera: _FakeCamera(), uploads: queue, onSessionCreated: (s) => created = s);
    await tapChip(tester, 'Com Bruno');
    await finish(tester);
    await tapSave(tester);

    expect(find.text('Só dá para gravar com os seus amigos.'), findsOneWidget);
    expect(created, isNull);
    expect(queue.state.value.isEmpty, isTrue);

    // Tirar o amigo limpa o erro; o servidor agora recusa o nome.
    await tester.ensureVisible(find.text('Bruno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bruno'));
    await tester.pump();
    expect(find.text('Só dá para gravar com os seus amigos.'), findsNothing);

    backend.saveError = const SessionsFailure('Dê um nome para a sessão.', code: 'name');
    await tapSave(tester);
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    expect(find.text('Dê um nome para a sessão.'), findsOneWidget);
    expect(backend.savedSessions, hasLength(2));
    expect(backend.savedSessions[1], backend.savedSessions[0]); // mesmo id: reenvio idempotente
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
