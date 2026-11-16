import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/home/screens/player_screen.dart';

const _videoH1 = 'sessions/quinta01/highlights/lance01/video.mp4';
const _videoH2 = 'sessions/quinta01/highlights/lance02/video.mp4';

Highlight _highlight(
  String id, {
  required String title,
  required Duration offset,
  String? videoPath,
  HighlightStatus status = HighlightStatus.uploaded,
  String? localPath,
}) =>
    Highlight(
      id: id,
      title: title,
      offset: offset,
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 34, 15),
      createdBy: 'alice',
      videoPath: videoPath,
      status: status,
      localPath: localPath,
    );

List<Highlight> _highlights() => [
      _highlight('h1', title: 'Jogada de cinema', offset: const Duration(minutes: 4, seconds: 15), videoPath: _videoH1),
      _highlight('h2', title: 'Ponto antológico', offset: const Duration(minutes: 12, seconds: 40), videoPath: _videoH2),
    ];

Widget _app(Widget home, {double textScale = 1}) {
  return MaterialApp(
    theme: clippoTheme(Brightness.dark),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Baixar que nunca termina: deixa o Player em "Carregando o lance…" sem tocar no
/// plugin de vídeo, que não existe nos testes.
/// Termina a troca de página sem `pumpAndSettle` (o carregando gira para sempre).
Future<void> _settlePage(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<File> _neverLoads(String path) => Completer<File>().future;

/// Player já aberto, tocando, mas esperando chegar o próximo pedaço (sem o plugin de vídeo).
class _BufferingController extends VideoPlayerController {
  _BufferingController() : super.networkUrl(Uri.parse('https://exemplo.invalid/video.mp4'));

  @override
  Future<void> initialize() async {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 30),
      size: const Size(1280, 720),
      isInitialized: true,
      isPlaying: true,
      isBuffering: true,
      buffered: [DurationRange(Duration.zero, const Duration(seconds: 6))],
    );
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seekTo(Duration position) async {}
}

/// Player aberto e tocando (sem o plugin de vídeo): play e pause só trocam o estado.
class _PlayingController extends VideoPlayerController {
  _PlayingController({this.size = const Size(720, 1280)})
      : super.networkUrl(Uri.parse('https://exemplo.invalid/video.mp4'));

  /// Em pé por padrão; `Size(1280, 720)` para um vídeo deitado.
  final Size size;

  @override
  Future<void> initialize() async {
    value = VideoPlayerValue(
      duration: const Duration(seconds: 30),
      size: size,
      isInitialized: true,
    );
  }

  final List<Duration> seeks = [];

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async => value = value.copyWith(playbackSpeed: speed);
}

/// Player que nunca termina de abrir (sem o plugin de vídeo, nos testes).
class _HangingController extends VideoPlayerController {
  _HangingController() : super.networkUrl(Uri.parse('https://exemplo.invalid/video.mp4'));

  @override
  Future<void> initialize() => Completer<void>().future;
}

/// O que a tela pediu ao Android sobre posição e barras (SystemChrome), na ordem.
List<String> _recordSystemChrome(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemChrome.setPreferredOrientations') {
      calls.add('orientations ${(call.arguments as List).join(',')}');
    } else if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
      calls.add('ui ${call.arguments}');
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

void main() {
  testWidgets('celular deitado: o vídeo ocupa a tela, sem cortar, e o lance continua o mesmo', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      initialIndex: 1,
      loadVideo: _neverLoads,
    )));
    await tester.pump();
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Baixar'), findsOneWidget);

    tester.view.physicalSize = const Size(915, 412);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Fechar'), findsOneWidget);
    expect(find.text('Carregando o lance…'), findsOneWidget);
    // Deitado, os mesmos controles por cima do vídeo.
    expect(find.bySemanticsLabel('Baixar'), findsOneWidget);

    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Baixar'), findsOneWidget);
  });

  group('controles por cima do vídeo', () {
    double controlsOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(of: find.bySemanticsLabel('Fechar'), matching: find.byType(AnimatedOpacity)).first,
        )
        .opacity;

    Future<_PlayingController> openPlaying(WidgetTester tester) async {
      _phone(tester);
      final controller = _PlayingController();
      await tester.pumpWidget(_app(PlayerScreen(
        sessionName: 'Pelada de quinta',
        highlights: _highlights(),
        streamVideo: (path) async => HighlightVideoStream(url: Uri.parse('https://exemplo.invalid/v.mp4'), headers: const {}),
        streamControllerFactory: (s) => controller,
      )));
      await tester.pump();
      await tester.pump();
      return controller;
    }

    testWidgets('tela cheia deita o celular e esconde as barras; o Voltar sai dela', (tester) async {
      final calls = _recordSystemChrome(tester);
      // Vídeo deitado.
      _phone(tester);
      final controller = _PlayingController(size: const Size(1280, 720));
      await tester.pumpWidget(_app(PlayerScreen(
        highlights: _highlights(),
        streamVideo: (path) async => HighlightVideoStream(url: Uri.parse('https://exemplo.invalid/v.mp4'), headers: const {}),
        streamControllerFactory: (s) => controller,
      )));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Tela cheia'));
      await tester.pump();
      expect(calls, ['ui SystemUiMode.immersiveSticky', 'orientations DeviceOrientation.landscapeLeft,DeviceOrientation.landscapeRight']);
      expect(find.bySemanticsLabel('Sair da tela cheia'), findsOneWidget);

      calls.clear();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(calls, ['ui SystemUiMode.edgeToEdge', 'orientations DeviceOrientation.portraitUp']);
      // Saiu da tela cheia, mas continua no Player.
      expect(find.bySemanticsLabel('Tela cheia'), findsOneWidget);
    });

    testWidgets('vídeo em pé: tela cheia só esconde as barras, sem deitar o celular', (tester) async {
      final calls = _recordSystemChrome(tester);
      await openPlaying(tester);
      await tester.tap(find.bySemanticsLabel('Tela cheia'));
      await tester.pump();
      expect(calls, ['ui SystemUiMode.immersiveSticky']);
    });

    testWidgets('fechar o Player em tela cheia devolve o app para em pé', (tester) async {
      final calls = _recordSystemChrome(tester);
      await openPlaying(tester);
      await tester.tap(find.bySemanticsLabel('Tela cheia'));
      await tester.pump();
      calls.clear();
      await tester.pumpWidget(const SizedBox());
      expect(calls, contains('orientations DeviceOrientation.portraitUp'));
      expect(calls, contains('ui SystemUiMode.edgeToEdge'));
    });

    testWidgets('voltar 5 segundos, sem passar do começo', (tester) async {
      final controller = await openPlaying(tester);
      controller.value = controller.value.copyWith(position: const Duration(seconds: 12));
      await tester.tap(find.bySemanticsLabel('Voltar 5 segundos'));
      await tester.pump();
      expect(controller.seeks.last, const Duration(seconds: 7));

      controller.value = controller.value.copyWith(position: const Duration(seconds: 3));
      await tester.tap(find.bySemanticsLabel('Voltar 5 segundos'));
      await tester.pump();
      expect(controller.seeks.last, Duration.zero);
    });

    testWidgets('os botões de 5 s ficam dos dois lados do play', (tester) async {
      await openPlaying(tester);
      final play = tester.getCenter(find.bySemanticsLabel('Pausar'));
      final back = tester.getCenter(find.bySemanticsLabel('Voltar 5 segundos'));
      final forward = tester.getCenter(find.bySemanticsLabel('Avançar 5 segundos'));
      expect(back.dx, lessThan(play.dx));
      expect(forward.dx, greaterThan(play.dx));
      expect(back.dy, closeTo(play.dy, 1));
      expect(forward.dy, closeTo(play.dy, 1));
    });

    testWidgets('dois dedos na tela (pinça) não trocam de lance', (tester) async {
      await openPlaying(tester);
      final first = await tester.startGesture(const Offset(150, 457), pointer: 1);
      final second = await tester.startGesture(const Offset(260, 457), pointer: 2);
      await tester.pump();
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isA<NeverScrollableScrollPhysics>());

      await first.moveBy(const Offset(-80, 0));
      await second.moveBy(const Offset(80, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pump(const Duration(milliseconds: 500));
      // Abrir os dedos deu zoom: continua no mesmo lance e, com zoom, deslizar não troca.
      expect(find.text('1 de 2'), findsOneWidget);
      final zoom = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!;
      expect(zoom.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('avançar 5 segundos, sem passar do fim', (tester) async {
      final controller = await openPlaying(tester);
      await tester.tap(find.bySemanticsLabel('Avançar 5 segundos'));
      await tester.pump();
      expect(controller.seeks.last, const Duration(seconds: 5));

      controller.value = controller.value.copyWith(position: const Duration(seconds: 28));
      await tester.tap(find.bySemanticsLabel('Avançar 5 segundos'));
      await tester.pump();
      expect(controller.seeks.last, const Duration(seconds: 30));
    });

    testWidgets('segurar o lado direito toca em 2x até soltar', (tester) async {
      final controller = await openPlaying(tester);
      final gesture = await tester.startGesture(const Offset(380, 457));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(controller.value.playbackSpeed, 2);
      expect(find.bySemanticsLabel('Velocidade 2x'), findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(controller.value.playbackSpeed, 1);
      expect(find.bySemanticsLabel('Velocidade 2x'), findsNothing);
    });

    testWidgets('segurar fora do lado direito não muda a velocidade', (tester) async {
      final controller = await openPlaying(tester);
      final gesture = await tester.startGesture(const Offset(60, 457));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pump();
      expect(controller.value.playbackSpeed, 1);
    });

    testWidgets('pinça no vídeo dá zoom e, com zoom, arrastar não troca de lance', (tester) async {
      await openPlaying(tester);
      final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(viewer.maxScale, greaterThan(1));
      viewer.transformationController!.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isA<NeverScrollableScrollPhysics>());

      viewer.transformationController!.value = Matrix4.identity();
      await tester.pump();
      expect(tester.widget<PageView>(find.byType(PageView)).physics, isNull);
    });

    testWidgets('somem sozinhos com o vídeo tocando e voltam ao tocar no vídeo', (tester) async {
      await openPlaying(tester);
      expect(controlsOpacity(tester), 1);
      expect(find.bySemanticsLabel('Pausar'), findsOneWidget);

      await tester.pump(ClippoMotion.playerControls);
      await tester.pump(ClippoMotion.enable);
      expect(controlsOpacity(tester), 0);

      await tester.tapAt(const Offset(206, 457));
      await tester.pump();
      expect(controlsOpacity(tester), 1);

      // Tocar de novo esconde, como nos players de vídeo conhecidos.
      await tester.tapAt(const Offset(206, 300));
      await tester.pump();
      expect(controlsOpacity(tester), 0);
    });

    testWidgets('pausado, os controles ficam à vista', (tester) async {
      await openPlaying(tester);
      await tester.tap(find.bySemanticsLabel('Pausar'));
      await tester.pump();
      expect(find.bySemanticsLabel('Reproduzir'), findsOneWidget);

      await tester.pump(ClippoMotion.playerControls * 2);
      expect(controlsOpacity(tester), 1);
    });

    testWidgets('baixar e compartilhar são só ícones, sem texto', (tester) async {
      await openPlaying(tester);
      expect(find.bySemanticsLabel('Baixar'), findsOneWidget);
      expect(find.bySemanticsLabel('Compartilhar'), findsOneWidget);
      expect(find.text('Baixar'), findsNothing);
      expect(find.text('Compartilhar'), findsNothing);
    });

    testWidgets('o vídeo ocupa a largura toda da tela', (tester) async {
      await openPlaying(tester);
      expect(tester.getSize(find.byType(VideoPlayer)).width, 412);
    });
  });

  testWidgets('mostra a sessão, o lance e carrega o vídeo pelo repositório', (tester) async {
    _phone(tester);
    final pedidos = <String>[];

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      loadVideo: (path) {
        pedidos.add(path);
        return Completer<File>().future;
      },
    )));
    await tester.pump();

    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Jogada de cinema'), findsOneWidget);
    expect(find.text('00:04:15 · 30s'), findsOneWidget);
    expect(find.text('Carregando o lance…'), findsOneWidget);
    expect(pedidos, [_videoH1]);
  });

  testWidgets('lance ainda enviando mostra "enviando" e não tenta baixar', (tester) async {
    _phone(tester);
    var baixou = 0;
    var salvou = 0;

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: [
        _highlight(
          'h1',
          title: 'Jogada de cinema',
          offset: const Duration(minutes: 4, seconds: 15),
          videoPath: _videoH1,
          status: HighlightStatus.pending,
        ),
      ],
      loadVideo: (path) async {
        baixou++;
        return File(path);
      },
      saveToGallery: (path, _) async => salvou++,
    )));
    await tester.pump();

    expect(find.text('Enviando o lance…'), findsOneWidget);
    expect(find.text('00:04:15 · enviando…'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Baixar'));
    await tester.tap(find.bySemanticsLabel('Compartilhar'));
    await tester.pump();

    expect(baixou, 0);
    expect(salvou, 0);
  });

  group('streaming da nuvem', () {
    final source = HighlightVideoStream(
      url: Uri.parse('https://firebasestorage.googleapis.com/v0/b/b/o/x?alt=media'),
      headers: {'Authorization': 'Firebase token'},
    );

    testWidgets('toca enquanto o vídeo chega, sem baixar o arquivo inteiro antes', (tester) async {
      _phone(tester);
      final pedidos = <String>[];
      final abertos = <HighlightVideoStream>[];
      var baixou = 0;

      await tester.pumpWidget(_app(PlayerScreen(
        highlights: _highlights(),
        streamVideo: (path) async {
          pedidos.add(path);
          return source;
        },
        streamControllerFactory: (s) {
          abertos.add(s);
          // Fica "abrindo" para sempre: o plugin de vídeo não existe nos testes.
          return _HangingController();
        },
        loadVideo: (path) async {
          baixou++;
          return File(path);
        },
      )));
      await tester.pump();
      await tester.pump();

      expect(pedidos, [_videoH1]);
      expect(abertos.single.headers['Authorization'], 'Firebase token');
      expect(baixou, 0);
      expect(find.text('Carregando o lance…'), findsOneWidget);
    });

    testWidgets('esperando o próximo pedaço, mostra carregando em vez de pausar', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(PlayerScreen(
        highlights: _highlights(),
        streamVideo: (path) async => source,
        streamControllerFactory: (s) => _BufferingController(),
      )));
      await tester.pump();
      await tester.pump();

      expect(find.bySemanticsLabel('Carregando o vídeo'), findsWidgets);
      expect(find.bySemanticsLabel('Pausar'), findsNothing);
    });

    testWidgets('se o streaming falhar, baixa o arquivo inteiro e toca', (tester) async {
      _phone(tester);
      final pedidos = <String>[];

      await tester.pumpWidget(_app(PlayerScreen(
        highlights: _highlights(),
        streamVideo: (path) async => throw const HighlightMediaFailure('sem streaming'),
        loadVideo: (path) {
          pedidos.add(path);
          return Completer<File>().future;
        },
      )));
      await tester.pump();
      await tester.pump();

      expect(pedidos, [_videoH1]);
    });
  });

  group('MP4 ainda no celular de quem gravou', () {
    const local = '/data/highlights/lance01.mp4';
    final pending = _highlight(
      'h1',
      title: 'Jogada de cinema',
      offset: const Duration(minutes: 4, seconds: 15),
      status: HighlightStatus.pending,
      localPath: local,
    );

    testWidgets('toca direto do celular, antes de subir e sem internet', (tester) async {
      _phone(tester);
      final abertos = <String>[];
      var baixou = 0;

      await tester.pumpWidget(_app(PlayerScreen(
        highlights: [pending],
        localFileExists: (path) async => true,
        loadVideo: (path) async {
          baixou++;
          return File(path);
        },
        // O plugin de vídeo não existe nos testes: basta ver qual arquivo o player abriria.
        controllerFactory: (file) {
          abertos.add(file.path);
          throw StateError('sem plugin de vídeo nos testes');
        },
      )));
      await tester.pumpAndSettle();

      expect(abertos, [local]);
      expect(baixou, 0);
      expect(find.text('Enviando o lance…'), findsNothing);
    });

    testWidgets('Baixar só copia o arquivo da pasta do app para a galeria', (tester) async {
      _phone(tester);
      final copiados = <String>[];
      var daNuvem = 0;

      await tester.pumpWidget(_app(PlayerScreen(
        highlights: [pending],
        localFileExists: (path) async => true,
        loadVideo: _neverLoads,
        controllerFactory: (file) => throw StateError('sem plugin de vídeo nos testes'),
        saveFileToGallery: (file) async => copiados.add(file.path),
        saveToGallery: (path, _) async => daNuvem++,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Baixar'));
      await tester.pump();
      await tester.pump();

      expect(copiados, [local]);
      expect(daNuvem, 0);
      expect(find.text('Lance salvo na galeria.'), findsOneWidget);
    });

    testWidgets('o MP4 já foi apagado (o lance subiu): toca e baixa da nuvem', (tester) async {
      _phone(tester);
      final pedidos = <String>[];
      final salvos = <String>[];
      var copiados = 0;

      await tester.pumpWidget(_app(PlayerScreen(
        highlights: [
          _highlight(
            'h1',
            title: 'Jogada de cinema',
            offset: const Duration(minutes: 4, seconds: 15),
            videoPath: _videoH1,
            localPath: local,
          ),
        ],
        localFileExists: (path) async => false,
        loadVideo: (path) {
          pedidos.add(path);
          return Completer<File>().future;
        },
        saveFileToGallery: (file) async => copiados++,
        saveToGallery: (path, _) async => salvos.add(path),
      )));
      await tester.pump();
      await tester.pump();
      expect(pedidos, [_videoH1]);

      await tester.tap(find.bySemanticsLabel('Baixar'));
      await tester.pump();
      await tester.pump();
      expect(salvos, [_videoH1]);
      expect(copiados, 0);
    });
  });

  testWidgets('erro ao baixar vira frase amigável e dá para tentar de novo', (tester) async {
    _phone(tester);
    var tentativas = 0;

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      loadVideo: (path) async {
        tentativas++;
        throw const HighlightMediaFailure('Você não tem acesso a esse lance.', code: 'unauthorized');
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Você não tem acesso a esse lance.'), findsOneWidget);
    expect(find.textContaining('unauthorized'), findsNothing);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(tentativas, 2);
  });

  testWidgets('Baixar salva o vídeo do lance na galeria', (tester) async {
    _phone(tester);
    final salvos = <String>[];

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      initialIndex: 1,
      loadVideo: _neverLoads,
      saveToGallery: (path, _) async => salvos.add(path),
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Baixar'));
    await tester.pump();
    await tester.pump();

    expect(salvos, [_videoH2]);
    expect(find.text('Lance salvo na galeria.'), findsOneWidget);
  });

  testWidgets('Baixar mostra quanto do vídeo já chegou', (tester) async {
    _phone(tester);
    late ValueChanged<double> report;
    final done = Completer<void>();

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      initialIndex: 1,
      loadVideo: _neverLoads,
      saveToGallery: (path, onProgress) {
        report = onProgress;
        return done.future;
      },
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Baixar'));
    await tester.pump();
    expect(find.bySemanticsLabel('Baixando…'), findsOneWidget);

    report(0.42);
    await tester.pump();
    expect(find.bySemanticsLabel('Baixando 42 %'), findsOneWidget);

    report(1);
    await tester.pump();
    expect(find.bySemanticsLabel('Salvando na galeria…'), findsOneWidget);

    done.complete();
    await tester.pump();
    await tester.pump();
    expect(find.bySemanticsLabel('Baixar'), findsOneWidget);
    expect(find.text('Lance salvo na galeria.'), findsOneWidget);
  });

  testWidgets('Compartilhar manda o arquivo local do lance, não um link', (tester) async {
    _phone(tester);
    var chamadas = 0;
    File? compartilhado;
    Highlight? lance;

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      loadVideo: (path) {
        chamadas++;
        // A 1ª chamada é o carregamento do player; a 2ª, o compartilhar.
        if (chamadas == 1) return Completer<File>().future;
        return Future.value(File('/cache/clippo-videos/lance01.mp4'));
      },
      shareVideo: (file, highlight, sessionName) async {
        compartilhado = file;
        lance = highlight;
      },
    )));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Compartilhar'));
    await tester.pump();
    await tester.pump();

    expect(compartilhado?.path, '/cache/clippo-videos/lance01.mp4');
    expect(lance?.id, 'h1');
  });

  testWidgets('deslizar leva ao próximo e ao anterior lance da sessão (sem setas)', (tester) async {
    _phone(tester);
    final pedidos = <String>[];

    await tester.pumpWidget(_app(PlayerScreen(
      sessionName: 'Pelada de quinta',
      highlights: _highlights(),
      loadVideo: (path) {
        pedidos.add(path);
        return Completer<File>().future;
      },
    )));
    await tester.pump();

    // O indicador de carregando gira para sempre: avança o tempo em vez de esperar parar.
    expect(find.bySemanticsLabel('Próximo lance'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await _settlePage(tester);

    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Ponto antológico'), findsOneWidget);
    expect(find.text('00:12:40 · 30s'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(300, 0));
    await _settlePage(tester);

    expect(find.text('1 de 2'), findsOneWidget);
    expect(pedidos, [_videoH1, _videoH2, _videoH1]);
  });

  testWidgets('lance sem vídeo avisa em vez de tentar baixar', (tester) async {
    _phone(tester);
    var baixou = 0;
    await tester.pumpWidget(_app(PlayerScreen(
      highlights: [_highlight('h1', title: 'Jogada de cinema', offset: Duration.zero)],
      loadVideo: (path) async {
        baixou++;
        return File(path);
      },
    )));
    await tester.pump();

    expect(find.text('Esse lance ainda não tem vídeo.'), findsOneWidget);
    expect(baixou, 0);
  });

  testWidgets('sem lances, diz que não há nada para mostrar', (tester) async {
    await tester.pumpWidget(_app(const PlayerScreen()));
    await tester.pump();

    expect(find.text('Nenhum lance para mostrar.'), findsOneWidget);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('abre sem cortar (fonte ${scale * 100}%)', (tester) async {
      _phone(tester);

      await tester.pumpWidget(_app(
        PlayerScreen(
          sessionName: 'Pelada de quinta',
          highlights: _highlights(),
          loadVideo: _neverLoads,
        ),
        textScale: scale,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
