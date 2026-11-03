import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/home/screens/session_screen.dart';

Session _session({
  String id = 'quinta',
  String name = 'Pelada de quinta',
  int participants = 10,
  int highlightCount = 2,
}) {
  return Session.fromMap(id, {
    'name': name,
    'ownerId': 'alice',
    'participantIds': const ['alice', 'bob'],
    'participantsPreview': [
      {'uid': 'alice', 'name': 'Alice Prado', 'username': 'alice.prado'},
      {'uid': 'bob', 'name': 'Bruno Lima', 'username': 'bruno.lima'},
      for (var i = 2; i < (participants > 5 ? 5 : participants); i++)
        {'uid': 'u$i', 'name': 'Pessoa $i'},
    ],
    'participantCount': participants,
    'startedAt': DateTime(2026, 9, 11, 19, 30),
    'endedAt': DateTime(2026, 9, 11, 21, 12),
    'durationSeconds': 6120,
    'location': const {'label': 'Quadra do Parque'},
    'highlightCount': highlightCount,
  });
}

Highlight _highlight(
  String id, {
  required String title,
  required Duration offset,
  HighlightStatus status = HighlightStatus.uploaded,
}) {
  return Highlight(
    id: id,
    title: title,
    offset: offset,
    duration: const Duration(seconds: 30),
    savedAt: DateTime(2026, 9, 11, 19, 42, 40),
    createdBy: 'alice',
    status: status,
  );
}

Widget _app(
  Widget home, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: clippoTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

HighlightsSnapshot _fromServer(List<Highlight> items) =>
    HighlightsSnapshot(highlights: items, fromCache: false);

HighlightsSnapshot _fromCache(List<Highlight> items) =>
    HighlightsSnapshot(highlights: items, fromCache: true);

void main() {
  testWidgets('mostra cabeçalho da sessão e lista de highlights em ordem cronológica',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          highlights: Stream.value(
            _fromServer([
              _highlight(
                'h1',
                title: 'Jogada de cinema',
                offset: const Duration(minutes: 4, seconds: 15),
              ),
              _highlight(
                'h2',
                title: 'Ponto antológico',
                offset: const Duration(minutes: 12, seconds: 40),
                status: HighlightStatus.pending,
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sessões'), findsOneWidget);
    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
    expect(find.text('11 set 2026 · 1h 42min'), findsOneWidget);
    expect(find.text('Quadra do Parque'), findsOneWidget);
    expect(find.text('10 participantes'), findsOneWidget);
    expect(find.text('Highlights'), findsOneWidget);
    expect(find.text('2 lances salvos'), findsOneWidget);
    expect(find.text('Jogada de cinema'), findsOneWidget);
    expect(find.text('00:04:15 · 30s'), findsOneWidget);
    expect(find.text('Ponto antológico'), findsOneWidget);
    expect(find.text('00:12:40 · enviando…'), findsOneWidget);
  });

  testWidgets('criador pode editar nome e local da sessão (R12); não-criador não vê o botão',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Quem não é dono não vê o botão de editar.
    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          currentUserId: 'bob',
          highlights: Stream.value(_fromServer(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Editar sessão'), findsNothing);

    // O dono (alice) vê o botão e consegue editar a sessão.
    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          currentUserId: 'alice',
          highlights: Stream.value(_fromServer(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Editar sessão'));
    await tester.pumpAndSettle();

    expect(find.text('EDITAR\nSESSÃO.'), findsOneWidget);

    // Validação impede nome vazio.
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pump();
    expect(find.text('Informe o nome da sessão.'), findsOneWidget);

    // Nome e local válidos atualizam a tela da sessão.
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Futebol de sexta');
    await tester.enterText(find.byType(TextField).at(1), 'Arena Society');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.text('FUTEBOL DE\nSEXTA.'), findsOneWidget);
    expect(find.text('Arena Society'), findsOneWidget);
  });

  testWidgets('clicar nos participantes mostra a lista de usuários e abre o perfil ao tocar',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(participants: 2),
          highlights: Stream.value(_fromServer(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 participantes'));
    await tester.pumpAndSettle();

    expect(find.text('JOGARAM\nJUNTOS.'), findsOneWidget);
    expect(find.text('Alice Prado'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('Adicionar'), findsOneWidget);

    await tester.tap(find.text('Bruno Lima'));
    await tester.pumpAndSettle();

    expect(find.text('PERFIL DE\nBRUNO.'), findsOneWidget);
    expect(find.text('@bruno.lima'), findsOneWidget);
    expect(find.text('Adicionar amigo'), findsOneWidget);

    await tester.tap(find.text('Adicionar amigo'));
    await tester.pump();
    expect(find.text('Convite de amizade enviado'), findsOneWidget);
  });

  testWidgets('compartilhar sessão mostra link, QR Code e aviso de ter o app baixado',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(id: 'quinta-11set'),
          highlights: Stream.value(_fromServer(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Compartilhar sessão'));
    await tester.pumpAndSettle();

    expect(find.text('COMPARTILHAR\nSESSÃO.'), findsOneWidget);
    expect(find.text('É preciso ter o app Clippo baixado'), findsOneWidget);
    expect(find.text('QR Code da sessão'), findsOneWidget);
    expect(find.text('https://clippo.app/s/quinta-11set'), findsOneWidget);
    expect(find.text('Copiar link da sessão'), findsOneWidget);
  });

  testWidgets('sem highlights, mostra o estado vazio e o lembrete do gesto', (tester) async {
    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(highlightCount: 0),
          highlights: Stream.value(_fromServer(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lance salvo nessa sessão'), findsOneWidget);
    expect(find.textContaining(r'\ o /'), findsOneWidget);
  });

  testWidgets('enquanto carrega, mantém o cabeçalho e mostra esqueletos', (tester) async {
    final nunca = StreamController<HighlightsSnapshot>();
    addTearDown(nunca.close);

    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(highlightCount: 7),
          highlights: nunca.stream,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando highlights'), findsOneWidget);
    expect(find.text('7 lances salvos'), findsOneWidget);
  });

  testWidgets('erro de rede mostra frase amigável e botão Tentar de novo', (tester) async {
    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          highlights: Stream<HighlightsSnapshot>.error(
            FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('offline sem nada no cache avisa falta de internet em vez de sessão vazia',
      (tester) async {
    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          highlights: Stream.value(_fromCache(const <Highlight>[])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lance salvo nessa sessão'), findsNothing);
    expect(
      find.text('Sem internet. Os highlights aparecem assim que você conectar.'),
      findsOneWidget,
    );
  });

  testWidgets('tocar num highlight abre o Player no lance escolhido', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        SessionScreen(
          session: _session(),
          highlights: Stream.value(
            _fromServer([
              _highlight('h1', title: 'Lance 1', offset: const Duration(minutes: 4, seconds: 15)),
              _highlight('h2', title: 'Lance 2', offset: const Duration(minutes: 12, seconds: 40)),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ponto antológico'));
    await tester.pumpAndSettle();

    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Ponto antológico'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            SessionScreen(
              session: _session(participants: 10),
              highlights: Stream.value(
                _fromServer([
                  _highlight(
                    'h1',
                    title: 'Lance 1',
                    offset: const Duration(minutes: 4, seconds: 15),
                  ),
                  _highlight(
                    'h2',
                    title: 'Lance 2',
                    offset: const Duration(minutes: 12, seconds: 40),
                    status: HighlightStatus.pending,
                  ),
                ]),
              ),
            ),
            brightness: brightness,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
