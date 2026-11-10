import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
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
      saveToGallery: (path) async => salvou++,
    )));
    await tester.pump();

    expect(find.text('Enviando o lance…'), findsOneWidget);
    expect(find.text('00:04:15 · enviando…'), findsOneWidget);

    await tester.tap(find.text('Baixar'));
    await tester.tap(find.text('Compartilhar'));
    await tester.pump();

    expect(baixou, 0);
    expect(salvou, 0);
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
      saveToGallery: (path) async => salvos.add(path),
    )));
    await tester.pump();

    await tester.tap(find.text('Baixar'));
    await tester.pump();
    await tester.pump();

    expect(salvos, [_videoH2]);
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

    await tester.tap(find.text('Compartilhar'));
    await tester.pump();
    await tester.pump();

    expect(compartilhado?.path, '/cache/clippo-videos/lance01.mp4');
    expect(lance?.id, 'h1');
  });

  testWidgets('navega para o próximo e o anterior lance da sessão', (tester) async {
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
    await tester.tap(find.bySemanticsLabel('Próximo lance'));
    await _settlePage(tester);

    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Ponto antológico'), findsOneWidget);
    expect(find.text('00:12:40 · 30s'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Lance anterior'));
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
