import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/home/screens/home_screen.dart';

// A Início abre sem Firebase: os streams vêm pelo construtor, como o `home` de app.dart.
Session _session(String id, {required String name, int highlights = 7, int participants = 2}) {
  return Session.fromMap(id, {
    'name': name,
    'ownerId': 'alice',
    'participantIds': const ['alice', 'bob'],
    'participantsPreview': [
      for (var i = 0; i < (participants > 5 ? 5 : participants); i++)
        {'uid': 'u$i', 'name': 'Pessoa $i'},
    ],
    'participantCount': participants,
    'startedAt': DateTime(2026, 9, 11, 19, 30),
    'endedAt': DateTime(2026, 9, 11, 21, 12),
    'durationSeconds': 6120,
    'location': const {'label': 'Quadra do Parque'},
    'highlightCount': highlights,
  });
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

/// Atalho: o que o repositório devolveria com estas sessões, vindas do servidor.
SessionsSnapshot _fromServer(List<Session> sessions) =>
    SessionsSnapshot(sessions: sessions, fromCache: false);

SessionsSnapshot _fromCache(List<Session> sessions) =>
    SessionsSnapshot(sessions: sessions, fromCache: true);

HomeScreen _home(Stream<SessionsSnapshot> sessions, {UserProfile? me}) => HomeScreen(
      sessions: sessions,
      profile: Stream<UserProfile?>.value(
        me ?? const UserProfile(uid: 'alice', name: 'Gustavo Alves', username: 'gustavo'),
      ),
    );

void main() {
  testWidgets('lista as sessões, com o card mais recente já aberto', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_home(Stream.value(_fromServer([
      _session('quinta', name: 'Pelada de quinta'),
      _session('sabado', name: 'Vôlei de sábado', highlights: 1),
    ])))));
    await tester.pumpAndSettle();

    expect(find.text('SUAS\nSESSÕES.'), findsOneWidget);
    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('11 set 2026 · 7 highlights'), findsOneWidget);
    expect(find.text('11 set 2026 · 1 highlight'), findsOneWidget);
    // O primeiro card começa aberto: só ele mostra local e ação.
    expect(find.text('Quadra do Parque'), findsOneWidget);
    expect(find.text('Ver highlights'), findsOneWidget);
  });

  testWidgets('tocar no card fecha o aberto e abre o outro', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_home(Stream.value(_fromServer([
      _session('quinta', name: 'Pelada de quinta'),
      _session('sabado', name: 'Vôlei de sábado'),
    ])))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vôlei de sábado'));
    await tester.pumpAndSettle();

    // Só um card aberto por vez: uma ação na tela, não duas.
    expect(find.text('Ver highlights'), findsOneWidget);
  });

  testWidgets('sem sessões, convida a gravar a primeira', (tester) async {
    await tester.pumpWidget(_app(_home(Stream.value(_fromServer(const <Session>[])))));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma sessão ainda'), findsOneWidget);
    expect(find.text('Gravar primeira sessão'), findsOneWidget);
  });

  testWidgets('o botão do estado vazio chama quem ligou a Gravação', (tester) async {
    var gravou = 0;
    await tester.pumpWidget(_app(HomeScreen(
      sessions: Stream.value(_fromServer(const <Session>[])),
      profile: Stream<UserProfile?>.value(null),
      onRecord: () => gravou++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gravar primeira sessão'));
    await tester.pumpAndSettle();
    expect(gravou, 1);
  });

  testWidgets('erro de rede vira frase amigável, não código técnico', (tester) async {
    await tester.pumpWidget(_app(_home(Stream<SessionsSnapshot>.error(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')))));
    await tester.pumpAndSettle();

    expect(find.text('Sem internet. Suas sessões aparecem assim que você conectar.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
    // Nada de "unavailable", "FirebaseException" ou código na tela.
    expect(find.textContaining('unavailable'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
  });

  testWidgets('offline sem nada guardado NÃO diz "nenhuma sessão"', (tester) async {
    // Sem internet e sem cache, o Firestore devolve lista vazia do cache.
    // Dizer "Nenhuma sessão ainda" aqui seria mentira.
    await tester.pumpWidget(_app(_home(Stream.value(_fromCache(const <Session>[])))));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma sessão ainda'), findsNothing);
    expect(
      find.text('Sem internet. Suas sessões aparecem assim que você conectar.'),
      findsOneWidget,
    );
  });

  testWidgets('offline com sessões guardadas mostra a lista e avisa', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_home(Stream.value(_fromCache([
      _session('quinta', name: 'Pelada de quinta'),
    ])))));
    await tester.pumpAndSettle();

    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('Sem internet. Mostrando o que já estava no aparelho.'), findsOneWidget);
  });

  testWidgets('a lista se atualiza sozinha quando chega sessão nova', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final sessoes = StreamController<SessionsSnapshot>();
    addTearDown(sessoes.close);

    await tester.pumpWidget(_app(_home(sessoes.stream)));
    await tester.pump();
    expect(find.bySemanticsLabel('Carregando suas sessões'), findsOneWidget);

    // Primeiro acesso: ninguém gravou nada ainda.
    sessoes.add(_fromServer(const <Session>[]));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma sessão ainda'), findsOneWidget);

    // Outro participante salvou uma sessão: ela aparece sem recarregar a tela.
    sessoes.add(_fromServer([_session('quinta', name: 'Pelada de quinta')]));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma sessão ainda'), findsNothing);
    expect(find.text('Pelada de quinta'), findsOneWidget);
  });

  testWidgets('enquanto carrega, mostra esqueletos e nenhum texto de erro', (tester) async {
    final nunca = StreamController<SessionsSnapshot>();
    addTearDown(nunca.close);

    await tester.pumpWidget(_app(_home(nunca.stream)));
    await tester.pump();

    expect(find.bySemanticsLabel('Carregando suas sessões'), findsOneWidget);
    expect(find.text('Algo deu errado.'), findsNothing);
    expect(find.text('Nenhuma sessão ainda'), findsNothing);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_app(
          _home(Stream.value(_fromServer([
            _session('quinta', name: 'Pelada de quinta', participants: 10),
            _session('sabado', name: 'Vôlei de sábado'),
          ]))),
          brightness: brightness,
          textScale: scale,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('com mais de 5 participantes, mostra "+N"', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_home(Stream.value(_fromServer([
      _session('quinta', name: 'Pelada de quinta', participants: 10),
    ])))));
    await tester.pumpAndSettle();

    expect(find.text('+5'), findsOneWidget);
    expect(find.text('1h 42min · 10 participantes'), findsOneWidget);
  });
}
