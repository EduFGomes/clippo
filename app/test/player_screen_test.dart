import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/home/screens/player_screen.dart';

List<Highlight> _highlights() => [
      Highlight(
        id: 'h1',
        title: 'Jogada de cinema',
        offset: const Duration(minutes: 4, seconds: 15),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11, 19, 34, 15),
        createdBy: 'alice',
      ),
      Highlight(
        id: 'h2',
        title: 'Ponto antológico',
        offset: const Duration(minutes: 12, seconds: 40),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11, 19, 42, 40),
        createdBy: 'alice',
      ),
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

void main() {
  testWidgets('mostra nome da sessão, título criativo do lance e alterna reproduzir e pausar',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        PlayerScreen(
          sessionName: 'Pelada de quinta',
          highlights: _highlights(),
          initialIndex: 0,
        ),
      ),
    );

    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Jogada de cinema'), findsOneWidget);
    expect(find.text('00:04:15 · 30s'), findsOneWidget);
    expect(find.bySemanticsLabel('Pausar'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Pausar'));
    await tester.pump();

    expect(find.bySemanticsLabel('Reproduzir'), findsOneWidget);
  });

  testWidgets('navega para o próximo e o anterior highlight da sessão', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        PlayerScreen(
          sessionName: 'Pelada de quinta',
          highlights: _highlights(),
          initialIndex: 0,
          autoPlay: false,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Próximo lance'));
    await tester.pumpAndSettle();

    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Ponto antológico'), findsOneWidget);
    expect(find.text('00:12:40 · 30s'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Lance anterior'));
    await tester.pumpAndSettle();

    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Jogada de cinema'), findsOneWidget);
  });

  testWidgets('botão compartilhar aciona o callback do highlight atual', (tester) async {
    Highlight? shared;
    await tester.pumpWidget(
      _app(
        PlayerScreen(
          sessionName: 'Pelada de quinta',
          highlights: _highlights(),
          initialIndex: 1,
          autoPlay: false,
          onShare: (h) => shared = h,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Compartilhar highlight'));
    await tester.pump();

    expect(shared?.id, 'h2');
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('abre sem cortar (fonte ${scale * 100}%)', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          PlayerScreen(
            sessionName: 'Pelada de quinta',
            highlights: _highlights(),
            autoPlay: false,
          ),
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
