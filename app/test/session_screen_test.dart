import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_highlight_tile.dart';
import 'package:clippo/features/home/screens/session_screen.dart';

// A Sessão abre sem Firebase: repositórios e streams entram pelo construtor.
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

Friendship _friendship(String uid, String name, {required bool accepted}) => Friendship(
      id: 'alice_$uid',
      status: accepted ? FriendshipStatus.accepted : FriendshipStatus.pending,
      requestedBy: 'alice',
      requestedTo: uid,
      other: Friend(uid: uid, name: name, username: name.toLowerCase().replaceAll(' ', '.')),
    );

SessionMergeRequest _mergeRequest({
  required String into,
  required String from,
  required String by,
  required String to,
}) =>
    SessionMergeRequest(
      id: '${into}__$from',
      intoSessionId: into,
      fromSessionId: from,
      requestedBy: by,
      requestedTo: to,
      intoName: 'Sessão $into',
      fromName: 'Sessão $from',
    );

/// Registra as Functions chamadas, sem Firebase.
typedef _Calls = List<(String, Map<String, dynamic>)>;

SessionsRepository _repo(_Calls calls, {Map<String, dynamic> reply = const {}}) =>
    SessionsRepository(callFunction: (name, payload) async {
      calls.add((name, payload));
      return reply;
    });

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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

HighlightsSnapshot _fromServer(List<Highlight> items) =>
    HighlightsSnapshot(highlights: items, fromCache: false);

HighlightsSnapshot _fromCache(List<Highlight> items) =>
    HighlightsSnapshot(highlights: items, fromCache: true);

Stream<HighlightsSnapshot> _noHighlights() => Stream.value(_fromServer(const <Highlight>[]));

/// Miniaturas sem Firebase: devolve um arquivo para os caminhos de [files] e falha nos outros.
class _FakeMedia extends HighlightMediaRepository {
  _FakeMedia(this.files);

  final Map<String, String> files;
  final List<String> asked = [];

  @override
  Future<File> thumbnailFile(String storagePath) async {
    asked.add(storagePath);
    final local = files[storagePath];
    if (local == null) throw const HighlightMediaFailure('Esse lance ainda está sendo enviado.');
    return File(local);
  }
}

/// A fila de envio com a sessão `quinta` ainda no celular: um lance só local.
ValueNotifier<UploadQueueState> _queued({
  bool alsoOnServer = false,
  Map<String, String> thumbnails = const {},
}) =>
    ValueNotifier(UploadQueueState(thumbnails: thumbnails, sessions: [
      QueuedSession(
        sessionId: 'quinta',
        ownerUid: 'alice',
        name: 'Pelada de quinta',
        startedAt: DateTime(2026, 9, 11, 19, 30),
        endedAt: DateTime(2026, 9, 11, 21, 12),
        saved: alsoOnServer,
        highlights: const [
          QueuedHighlight(
            highlightId: 'h9',
            localPath: '/data/highlights/h9.mp4',
            offset: Duration(minutes: 20),
            duration: Duration(seconds: 30),
            title: 'Golaço',
          ),
        ],
      ),
    ]));

void main() {
  testWidgets('cada card mostra a miniatura do seu lance; sem ela, fica o desenho de quadra',
      (tester) async {
    _phone(tester);
    const thumb1 = 'sessions/quinta-0001/highlights/lance-0001/thumb.jpg';
    const thumb2 = 'sessions/quinta-0001/highlights/lance-0002/thumb.jpg';
    final media = _FakeMedia({thumb1: '/cache/clippo-thumbs/lance-0001.jpg'});
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      mediaRepository: media,
      highlights: Stream.value(_fromServer([
        _highlight('h1', title: 'Lance 1', offset: const Duration(minutes: 4))
            .copyWith(thumbnailPath: thumb1),
        // Lance antigo: o caminho existe no banco, mas a miniatura nunca subiu.
        _highlight('h2', title: 'Lance 2', offset: const Duration(minutes: 9))
            .copyWith(thumbnailPath: thumb2),
      ])),
    )));
    await tester.pump();
    await tester.pump();

    ClippoHighlightTile tile(String title) =>
        tester.widget(find.widgetWithText(ClippoHighlightTile, title));
    expect(media.asked, unorderedEquals([thumb1, thumb2]));
    expect((tile('Lance 1').thumbnail! as FileImage).file.path, '/cache/clippo-thumbs/lance-0001.jpg');
    expect(tile('Lance 2').thumbnail, isNull);
  });

  testWidgets('lance ainda no celular usa a miniatura do aparelho, sem pedir ao Storage',
      (tester) async {
    _phone(tester);
    final media = _FakeMedia(const {});
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(highlightCount: 1),
      mediaRepository: media,
      highlights: Stream.value(_fromCache(const [])),
      uploads: _queued(thumbnails: const {'h9': '/data/highlights/h9.jpg'}),
    )));
    await tester.pump();
    await tester.pump();

    final tile = tester.widget<ClippoHighlightTile>(find.widgetWithText(ClippoHighlightTile, 'Golaço'));
    expect((tile.thumbnail! as FileImage).file.path, '/data/highlights/h9.jpg');
    expect(media.asked, isEmpty);
  });

  testWidgets('sem internet, os lances ainda no celular aparecem para assistir antes de subir',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(highlightCount: 1),
      highlights: Stream.value(_fromCache(const [])),
      uploads: _queued(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Sem internet. Os highlights aparecem assim que você conectar.'), findsNothing);
    expect(find.text('Golaço'), findsOneWidget);
    expect(find.text('00:20:00 · enviando…'), findsOneWidget);
  });

  testWidgets('sessão só no celular e sem lances abre vazia, sem erro de carregamento',
      (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];
    final discarded = <String>[];
    final queue = ValueNotifier(UploadQueueState(sessions: [
      QueuedSession(
        sessionId: 'quinta',
        ownerUid: 'alice',
        name: 'Pelada de quinta',
        startedAt: DateTime(2026, 9, 11, 19, 30),
        endedAt: DateTime(2026, 9, 11, 21, 12),
      ),
    ]));
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(highlightCount: 0),
      currentUserId: 'alice',
      // O Firestore não tem a sessão: ler os lances lá dá "sem permissão".
      highlights: Stream.error(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
      uploads: queue,
      repository: SessionsRepository(callFunction: (name, payload) async {
        calls.add((name, payload));
        throw FirebaseFunctionsException(code: 'unavailable', message: 'offline');
      }),
      discardUploads: (id) async {
        discarded.add(id);
        queue.value = const UploadQueueState();
      },
    )));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lance salvo nessa sessão'), findsOneWidget);
    expect(find.text('A sessão está guardada neste celular e sobe quando você conectar.'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsNothing);
    // Editar e juntar dependem do servidor.
    expect(find.bySemanticsLabel('Editar sessão'), findsNothing);
    expect(find.text('Juntar com outra sessão'), findsNothing);

    // Excluir sem internet: sair da fila basta.
    await tester.ensureVisible(find.text('Excluir sessão'));
    await tester.tap(find.text('Excluir sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Excluir sessão')));
    await tester.pumpAndSettle();
    expect(discarded, ['quinta']);
    expect(find.text('Sessão excluída.'), findsOneWidget);
  });

  testWidgets('lances do servidor e os que só estão no celular aparecem juntos, em ordem',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      highlights: Stream.value(_fromServer([
        _highlight('h1', title: 'Jogada de cinema', offset: const Duration(minutes: 4, seconds: 15)),
      ])),
      uploads: _queued(alsoOnServer: true),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Jogada de cinema'), findsOneWidget);
    expect(find.text('Golaço'), findsOneWidget);
    expect(find.text('2 lances salvos'), findsOneWidget);
  });

  testWidgets('título: uma palavra fica só ela; nome longo diminui em vez de virar várias linhas',
      (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(SessionScreen(session: _session(name: 'Pelada'), highlights: _noHighlights())));
    await tester.pumpAndSettle();
    expect(find.text('PELADA.'), findsOneWidget);
    expect(find.textContaining('SESSÃO'), findsNothing);

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(id: 'longa', name: 'Campeonato interestadual de futevôlei'),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();
    final title = tester.widget<Text>(find.text('CAMPEONATO INTERESTADUAL DE\nFUTEVÔLEI.'));
    expect(title.style!.fontSize, lessThan(ClippoText.displayL.fontSize!));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mostra cabeçalho da sessão e lista de highlights em ordem cronológica',
      (tester) async {
    _phone(tester);

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      highlights: Stream.value(_fromServer([
        _highlight('h1', title: 'Jogada de cinema', offset: const Duration(minutes: 4, seconds: 15)),
        _highlight(
          'h2',
          title: 'Ponto antológico',
          offset: const Duration(minutes: 12, seconds: 40),
          status: HighlightStatus.pending,
        ),
      ])),
    )));
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

  testWidgets('quem não é dono não vê editar nem juntar; vê "Sair da sessão"', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'bob',
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Editar sessão'), findsNothing);
    expect(find.text('Juntar com outra sessão'), findsNothing);
    expect(find.text('Excluir sessão'), findsNothing);
    expect(find.text('Sair da sessão'), findsOneWidget);
    // Não existe mais sessão aberta/fechada nem compartilhar a sessão por link/QR.
    expect(find.text('Sessão aberta'), findsNothing);
    expect(find.bySemanticsLabel('Compartilhar sessão'), findsNothing);
  });

  testWidgets('editar sessão: sair com mudanças pergunta antes de descartar; sem mudanças, só sai',
      (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'alice',
      repository: _repo(calls),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    // Sem mudanças: volta direto.
    await tester.tap(find.bySemanticsLabel('Editar sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Data'), findsOneWidget);
    expect(find.text('11 set 2026'), findsOneWidget);
    expect(find.text('19:30 – 21:12'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR\nSESSÃO.'), findsNothing);

    // Com mudanças: pergunta; "Continuar editando" fica, "Descartar" sai sem chamar o servidor.
    await tester.tap(find.bySemanticsLabel('Editar sessão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Outro nome');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Sair sem salvar?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR\nSESSÃO.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar alterações'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR\nSESSÃO.'), findsNothing);
    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
    expect(calls, isEmpty);
  });

  testWidgets('dono edita: valida e chama updateSession com os dados normalizados (R12)',
      (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(participants: 2),
      currentUserId: 'alice',
      repository: _repo(calls, reply: {'sessionId': 'quinta'}),
      friendships: Stream.value([
        _friendship('caio01', 'Caio Nunes', accepted: true),
        _friendship('dani01', 'Dani Reis', accepted: false),
      ]),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Editar sessão'));
    await tester.pumpAndSettle();
    expect(find.text('EDITAR\nSESSÃO.'), findsOneWidget);
    // "Adicionar" lista os amigos aceitos, não quem só tem pedido pendente.
    expect(find.bySemanticsLabel('Adicionar Caio Nunes'), findsOneWidget);
    expect(find.bySemanticsLabel('Adicionar Dani Reis'), findsNothing);

    // Nome vazio: erro embaixo do campo e nada vai para o servidor.
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pump();
    expect(find.text('Dê um nome para a sessão.'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.enterText(find.byType(TextField).first, '  Futebol   de sexta ');
    await tester.enterText(find.byType(TextField).at(1), ' Arena   Society ');
    await tester.ensureVisible(find.bySemanticsLabel('Adicionar Caio Nunes'));
    await tester.tap(find.bySemanticsLabel('Adicionar Caio Nunes'));
    await tester.pump();
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.$1, 'updateSession');
    expect(calls.single.$2, {
      'sessionId': 'quinta',
      'name': 'Futebol de sexta',
      'location': 'Arena Society',
      'participantIds': ['bob', 'caio01'],
    });
    expect(find.text('FUTEBOL DE\nSEXTA.'), findsOneWidget);
    expect(find.text('Arena Society'), findsOneWidget);
    expect(find.text('3 participantes'), findsOneWidget);
  });

  testWidgets('erro do servidor aparece embaixo do campo que ele apontou', (tester) async {
    _phone(tester);
    final repo = SessionsRepository(callFunction: (name, payload) async {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'O local pode ter até 80 caracteres.',
        details: const {'field': 'location'},
      );
    });

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(participants: 2),
      currentUserId: 'alice',
      repository: repo,
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Editar sessão'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Salvar alterações'));
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    // Continua na edição, com a mensagem pronta do servidor.
    expect(find.text('EDITAR\nSESSÃO.'), findsOneWidget);
    expect(find.text('O local pode ter até 80 caracteres.'), findsOneWidget);
  });

  testWidgets('dono exclui a sessão só depois de confirmar; sai da fila antes do servidor',
      (tester) async {
    _phone(tester);
    final order = <String>[];
    final calls = <(String, Map<String, dynamic>)>[];
    final repo = SessionsRepository(callFunction: (name, payload) async {
      order.add(name);
      calls.add((name, payload));
      return {'sessionId': 'quinta'};
    });

    await tester.pumpWidget(_app(Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => SessionScreen(
          session: _session(),
          currentUserId: 'alice',
          repository: repo,
          highlights: _noHighlights(),
          discardUploads: (id) async => order.add('discard:$id'),
        ),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Excluir sessão'));
    await tester.tap(find.text('Excluir sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir sessão?'), findsOneWidget);
    expect(find.textContaining('somem para todos os participantes. Não dá para desfazer.'), findsOneWidget);

    await tester.tap(find.text('Manter sessão'));
    await tester.pumpAndSettle();
    expect(order, isEmpty);

    await tester.tap(find.text('Excluir sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Excluir sessão')));
    await tester.pumpAndSettle();

    expect(order, ['discard:quinta', 'deleteSession']);
    expect(calls.single.$2, {'sessionId': 'quinta'});
    expect(find.text('Sessão excluída.'), findsOneWidget);
  });

  testWidgets('se o servidor recusar a exclusão, a tela continua e diz por quê', (tester) async {
    _phone(tester);
    final repo = SessionsRepository(callFunction: (_, _) async {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Essa sessão tem lances de outra sessão juntada e ainda não dá para excluir.',
      );
    });
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'alice',
      repository: repo,
      highlights: _noHighlights(),
      discardUploads: (_) async {},
    )));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Excluir sessão'));
    await tester.tap(find.text('Excluir sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Excluir sessão')));
    await tester.pumpAndSettle();

    expect(find.text('Essa sessão tem lances de outra sessão juntada e ainda não dá para excluir.'), findsOneWidget);
    expect(find.text('Excluir sessão'), findsOneWidget);
  });

  testWidgets('participante sai da sessão só depois de confirmar', (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'bob',
      repository: _repo(calls, reply: {'sessionId': 'quinta'}),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sair da sessão'));
    await tester.tap(find.text('Sair da sessão'));
    await tester.pumpAndSettle();
    expect(find.text('Sair da sessão?'), findsOneWidget);

    await tester.tap(find.text('Ficar'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);

    await tester.tap(find.text('Sair da sessão'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Sair da sessão')));
    await tester.pumpAndSettle();

    expect(calls.single.$1, 'leaveSession');
    expect(calls.single.$2, {'sessionId': 'quinta'});
  });

  testWidgets('pedido de juntar recebido mostra Aceitar e chama acceptSessionMerge',
      (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];

    // alice é dona de "quinta"; bob pediu para juntá-la à sessão dele.
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'alice',
      repository: _repo(calls),
      mergeRequests: Stream.value([
        _mergeRequest(into: 'tenis01', from: 'quinta', by: 'bob', to: 'alice'),
      ]),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Juntar sessões?'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
    await tester.tap(find.text('Aceitar'));
    await tester.pumpAndSettle();

    expect(calls.single.$1, 'acceptSessionMerge');
    expect(calls.single.$2, {'requestId': 'tenis01__quinta'});
  });

  testWidgets('quem pediu para juntar vê "esperando" e pode desistir', (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      currentUserId: 'alice',
      repository: _repo(calls),
      mergeRequests: Stream.value([
        _mergeRequest(into: 'quinta', from: 'tenis01', by: 'alice', to: 'bob'),
      ]),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Esperando o outro dono'), findsOneWidget);
    expect(find.text('Aceitar'), findsNothing);
    await tester.tap(find.text('Desistir'));
    await tester.pumpAndSettle();

    expect(calls.single.$1, 'cancelSessionMerge');
    expect(calls.single.$2, {'requestId': 'quinta__tenis01'});
  });

  testWidgets('dono pede para juntar uma sessão do mesmo jogo (D18)', (tester) async {
    _phone(tester);
    final calls = <(String, Map<String, dynamic>)>[];
    final minha = _session();
    final doBruno = Session.fromMap('tenis01', {
      'name': 'Tênis do Bruno',
      'ownerId': 'bob',
      'participantIds': const ['bob', 'alice'],
      'participantsPreview': const [
        {'uid': 'bob', 'name': 'Bruno Lima'},
      ],
      'startedAt': DateTime(2026, 9, 11, 19, 40),
      'endedAt': DateTime(2026, 9, 11, 21, 0),
      'durationSeconds': 4800,
      'highlightCount': 3,
    });
    final outroDia = Session.fromMap('outro01', {
      'name': 'Pelada antiga',
      'ownerId': 'bob',
      'participantIds': const ['bob', 'alice'],
      'startedAt': DateTime(2026, 9, 1, 19, 40),
      'endedAt': DateTime(2026, 9, 1, 21, 0),
      'durationSeconds': 4800,
    });

    await tester.pumpWidget(_app(SessionScreen(
      session: minha,
      currentUserId: 'alice',
      repository: _repo(calls, reply: {'requestId': 'quinta__tenis01'}),
      mySessions: Stream.value(
        SessionsSnapshot(sessions: [minha, doBruno, outroDia], fromCache: false),
      ),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Juntar com outra sessão'));
    await tester.tap(find.text('Juntar com outra sessão'));
    await tester.pumpAndSettle();

    expect(find.text('JUNTAR\nSESSÕES.'), findsOneWidget);
    expect(find.text('Tênis do Bruno'), findsOneWidget);
    // Sessão de outro dia não é "o mesmo jogo".
    expect(find.text('Pelada antiga'), findsNothing);

    await tester.tap(find.text('Tênis do Bruno'));
    await tester.pumpAndSettle();

    expect(calls.single.$1, 'requestSessionMerge');
    expect(calls.single.$2, {'intoSessionId': 'quinta', 'fromSessionId': 'tenis01'});
    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
  });

  testWidgets('participantes: lista quem jogou, abre o perfil e pede amizade pelo @',
      (tester) async {
    _phone(tester);
    final pedidos = <Map<String, dynamic>>[];
    final friends = FriendsRepository(callFunction: (name, payload) async {
      pedidos.add(payload);
      return {'status': 'pending'};
    });

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(participants: 2),
      currentUserId: 'alice',
      friendsRepository: friends,
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 participantes'));
    await tester.pumpAndSettle();

    expect(find.text('JOGARAM\nJUNTOS.'), findsOneWidget);
    expect(find.text('Alice Prado'), findsOneWidget);
    expect(find.text('Bruno Lima'), findsOneWidget);

    await tester.tap(find.text('Bruno Lima'));
    await tester.pumpAndSettle();

    expect(find.text('PERFIL DE\nBRUNO.'), findsOneWidget);
    expect(find.text('@bruno.lima'), findsOneWidget);

    await tester.tap(find.text('Adicionar amigo'));
    await tester.pumpAndSettle();
    expect(pedidos, [
      {'username': 'bruno.lima'},
    ]);
    expect(find.text('Pedido de amizade enviado'), findsOneWidget);
  });

  testWidgets('participantes: enquanto o pedido de amizade vai, o botão mostra "Enviando…"',
      (tester) async {
    _phone(tester);
    final resposta = Completer<Map<String, dynamic>>();
    var pedidos = 0;
    final friends = FriendsRepository(callFunction: (name, payload) {
      pedidos++;
      return resposta.future;
    });

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(participants: 2),
      currentUserId: 'alice',
      friendsRepository: friends,
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 participantes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'));
    await tester.pump();
    expect(find.text('Enviando…'), findsOneWidget);

    // Um segundo toque enquanto envia não manda outro pedido.
    await tester.tap(find.text('Enviando…'));
    await tester.pump();
    expect(pedidos, 1);

    resposta.complete({'status': 'pending'});
    await tester.pumpAndSettle();
    expect(find.text('Enviando…'), findsNothing);
    expect(find.text('Enviado'), findsOneWidget);
  });

  testWidgets('sem highlights, mostra o estado vazio e o lembrete do gesto', (tester) async {
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(highlightCount: 0),
      highlights: _noHighlights(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lance salvo nessa sessão'), findsOneWidget);
    expect(find.textContaining(r'\ o /'), findsOneWidget);
  });

  testWidgets('enquanto carrega, mantém o cabeçalho e mostra esqueletos', (tester) async {
    final nunca = StreamController<HighlightsSnapshot>();
    addTearDown(nunca.close);

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(highlightCount: 7),
      highlights: nunca.stream,
    )));
    await tester.pump();

    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
    expect(find.bySemanticsLabel('Carregando highlights'), findsOneWidget);
    expect(find.text('7 lances salvos'), findsOneWidget);
  });

  testWidgets('erro de rede mostra frase amigável e botão Tentar de novo', (tester) async {
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      highlights: Stream<HighlightsSnapshot>.error(
        FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('offline sem nada no cache avisa falta de internet em vez de sessão vazia',
      (tester) async {
    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      highlights: Stream.value(_fromCache(const <Highlight>[])),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum lance salvo nessa sessão'), findsNothing);
    expect(
      find.text('Sem internet. Os highlights aparecem assim que você conectar.'),
      findsOneWidget,
    );
  });

  testWidgets('tocar num highlight abre o Player no lance escolhido', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_app(SessionScreen(
      session: _session(),
      highlights: Stream.value(_fromServer([
        _highlight('h1', title: 'Lance 1', offset: const Duration(minutes: 4, seconds: 15)),
        _highlight('h2', title: 'Lance 2', offset: const Duration(minutes: 12, seconds: 40)),
      ])),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lance 2'));
    await tester.pumpAndSettle();

    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Lance 2'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        _phone(tester);

        await tester.pumpWidget(_app(
          SessionScreen(
            session: _session(participants: 10),
            currentUserId: 'alice',
            mergeRequests: Stream.value([
              _mergeRequest(into: 'tenis01', from: 'quinta', by: 'bob', to: 'alice'),
            ]),
            highlights: Stream.value(_fromServer([
              _highlight('h1', title: 'Lance 1', offset: const Duration(minutes: 4, seconds: 15)),
              _highlight(
                'h2',
                title: 'Lance 2',
                offset: const Duration(minutes: 12, seconds: 40),
                status: HighlightStatus.pending,
              ),
            ])),
          ),
          brightness: brightness,
          textScale: scale,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }

  group('renomear lance', () {
    List<Highlight> onServer() => [
          _highlight('lance-0001', title: 'Lance 1', offset: const Duration(minutes: 4))
              .copyWith(videoPath: 'sessions/quinta-0001/highlights/lance-0001/video.mp4'),
        ];

    testWidgets('o dono vê o lápis e renomeia; o nome passa pela Function', (tester) async {
      _phone(tester);
      final calls = <(String, Map<String, dynamic>)>[];
      await tester.pumpWidget(_app(SessionScreen(
        session: _session(),
        currentUserId: 'alice',
        repository: _repo(calls, reply: {'title': 'Voleio do Rafa'}),
        highlights: Stream.value(_fromServer(onServer())),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('clippo-highlight-rename')));
      await tester.pumpAndSettle();
      expect(find.text('Nome do lance'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Salvar nome'));
      await tester.pumpAndSettle();
      expect(find.text('Dê um nome ao lance.'), findsOneWidget);
      expect(calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'Voleio do Rafa');
      await tester.tap(find.text('Salvar nome'));
      await tester.pumpAndSettle();
      expect(calls.single.$1, 'renameHighlight');
      expect(calls.single.$2, {'sessionId': 'quinta', 'highlightId': 'lance-0001', 'title': 'Voleio do Rafa'});
      expect(find.text('Lance renomeado.'), findsOneWidget);
    });

    testWidgets('o dono apaga o lance só depois de confirmar; sai da fila antes do servidor', (tester) async {
      _phone(tester);
      final order = <String>[];
      final repo = SessionsRepository(callFunction: (name, payload) async {
        order.add('$name:${payload['highlightId']}');
        return {'highlightId': payload['highlightId']};
      });
      await tester.pumpWidget(_app(SessionScreen(
        session: _session(),
        currentUserId: 'alice',
        repository: repo,
        highlights: Stream.value(_fromServer(onServer())),
        discardHighlightUpload: (session, highlight) async => order.add('discard:$session/$highlight'),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('clippo-highlight-rename')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apagar lance'));
      await tester.tap(find.text('Apagar lance'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar lance?'), findsOneWidget);
      await tester.tap(find.text('Manter lance'));
      await tester.pumpAndSettle();
      expect(order, isEmpty);

      await tester.tap(find.text('Apagar lance'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Apagar lance')));
      await tester.pumpAndSettle();
      expect(order, ['discard:quinta/lance-0001', 'deleteHighlight:lance-0001']);
      expect(find.text('Lance apagado.'), findsOneWidget);
    });

    testWidgets('quem só participa não vê o lápis', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(SessionScreen(
        session: _session(),
        currentUserId: 'bob',
        repository: _repo([]),
        highlights: Stream.value(_fromServer(onServer())),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('clippo-highlight-rename')), findsNothing);
    });

    testWidgets('lance que ainda não chegou ao servidor não dá para renomear', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(SessionScreen(
        session: _session(highlightCount: 1),
        currentUserId: 'alice',
        highlights: Stream.value(_fromCache(const [])),
        uploads: _queued(),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Golaço'), findsOneWidget);
      expect(find.byKey(const ValueKey('clippo-highlight-rename')), findsNothing);
    });
  });
}
