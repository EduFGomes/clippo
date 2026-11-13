import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
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

    await tester.tap(find.bySemanticsLabel('Mostrar detalhes de Vôlei de sábado'));
    await tester.pumpAndSettle();

    // Só um card aberto por vez: uma ação na tela, não duas.
    expect(find.text('Ver highlights'), findsOneWidget);
    expect(find.bySemanticsLabel('Esconder detalhes de Vôlei de sábado'), findsOneWidget);
  });

  testWidgets('um toque num card fechado já abre a sessão', (tester) async {
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

    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Highlights'), findsOneWidget);
  });

  testWidgets('com muitas sessões, só monta os cards à vista (lista em slivers)', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_home(Stream.value(_fromServer([
      for (var i = 0; i < 80; i++) _session('s$i', name: 'Sessão $i'),
    ])))));
    await tester.pumpAndSettle();

    final built = find.byType(ClippoSessionCard, skipOffstage: false).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(80));

    // Rolando até o fim, o último aparece.
    await tester.scrollUntilVisible(find.text('Sessão 79'), 600);
    expect(find.text('Sessão 79'), findsOneWidget);
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

  testWidgets('"Gravar" ao lado do título abre a Gravação, mesmo com sessões na lista', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var gravou = 0;
    await tester.pumpWidget(_app(HomeScreen(
      sessions: Stream.value(_fromServer([_session('quinta', name: 'Pelada de quinta')])),
      profile: Stream<UserProfile?>.value(null),
      onRecord: () => gravou++,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Gravar uma sessão'));
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

  testWidgets('sessão salva sem internet aparece na Início, mesmo sem nada do servidor (R13)', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final queue = ValueNotifier(UploadQueueState(sessions: [
      QueuedSession(
        sessionId: 'sessao-123456',
        ownerUid: 'alice',
        name: 'Pelada de hoje',
        startedAt: DateTime(2026, 9, 12, 19, 30),
        endedAt: DateTime(2026, 9, 12, 20, 30),
        participantIds: const ['bob'],
        highlights: const [
          QueuedHighlight(
            highlightId: 'lance-0001',
            localPath: '/highlights/1.mp4',
            offset: Duration(minutes: 3),
            duration: Duration(seconds: 30),
          ),
        ],
        attempts: 1,
      ),
    ]));
    addTearDown(queue.dispose);

    // Sem internet e sem cache: antes, a tela só dizia "Sem internet" e a sessão sumia.
    await tester.pumpWidget(_app(HomeScreen(
      sessions: Stream.value(_fromCache(const <Session>[])),
      profile: Stream<UserProfile?>.value(null),
      currentUserId: 'alice',
      uploads: queue,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Pelada de hoje'), findsOneWidget);
    expect(find.text('12 set 2026 · 1 highlight · sobe quando conectar'), findsOneWidget);
    expect(find.text('1h · 2 participantes'), findsOneWidget);
    expect(find.text('Nenhuma sessão ainda'), findsNothing);

    // Chegou ao servidor: sai da fila e fica só a do Firestore, sem repetir.
    queue.value = const UploadQueueState();
    await tester.pumpAndSettle();
    expect(find.text('Pelada de hoje'), findsNothing);
  });

  testWidgets('sessão de outra conta na fila não aparece para quem está logado', (tester) async {
    final queue = ValueNotifier(UploadQueueState(sessions: [
      QueuedSession(
        sessionId: 'sessao-123456',
        ownerUid: 'bob',
        name: 'Pelada do Bob',
        startedAt: DateTime(2026, 9, 12, 19, 30),
        endedAt: DateTime(2026, 9, 12, 20, 30),
      ),
    ]));
    addTearDown(queue.dispose);

    await tester.pumpWidget(_app(HomeScreen(
      sessions: Stream.value(_fromServer(const <Session>[])),
      profile: Stream<UserProfile?>.value(null),
      currentUserId: 'alice',
      uploads: queue,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Pelada do Bob'), findsNothing);
    expect(find.text('Nenhuma sessão ainda'), findsOneWidget);
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

  group('pedidos para juntar sessões (D18)', () {
    SessionMergeRequest pedido({required String to}) => SessionMergeRequest(
          id: 'tenis01__quinta',
          intoSessionId: 'tenis01',
          fromSessionId: 'quinta',
          requestedBy: to == 'alice' ? 'bob' : 'alice',
          requestedTo: to,
          intoName: 'Tênis do Bruno',
          fromName: 'Pelada de quinta',
        );

    testWidgets('pedido recebido aparece no topo com Aceitar e chama acceptSessionMerge',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final calls = <(String, Map<String, dynamic>)>[];

      await tester.pumpWidget(_app(HomeScreen(
        sessions: Stream.value(_fromServer([_session('quinta', name: 'Pelada de quinta')])),
        profile: Stream<UserProfile?>.value(null),
        currentUserId: 'alice',
        mergeRequests: Stream.value([pedido(to: 'alice')]),
        repository: SessionsRepository(callFunction: (name, payload) async {
          calls.add((name, payload));
          return {};
        }),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Juntar sessões?'), findsOneWidget);
      expect(find.text('Recusar'), findsOneWidget);
      await tester.tap(find.text('Aceitar'));
      await tester.pumpAndSettle();

      expect(calls.single.$1, 'acceptSessionMerge');
      expect(calls.single.$2, {'requestId': 'tenis01__quinta'});
      expect(find.text('Juntar sessões?'), findsNothing);
    });

    testWidgets('pedido que eu fiz não aparece na Início', (tester) async {
      await tester.pumpWidget(_app(HomeScreen(
        sessions: Stream.value(_fromServer([_session('quinta', name: 'Pelada de quinta')])),
        profile: Stream<UserProfile?>.value(null),
        currentUserId: 'alice',
        mergeRequests: Stream.value([pedido(to: 'bob')]),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Juntar sessões?'), findsNothing);
      expect(find.text('Aceitar'), findsNothing);
    });
  });
}
