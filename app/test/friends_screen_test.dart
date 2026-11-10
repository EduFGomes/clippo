import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/friends/screens/friends_screen.dart';

const _me = 'meuUid';

/// Repositório sem Firebase: guarda as chamadas e devolve o que o teste mandar.
class _FakeFriendsRepository extends FriendsRepository {
  _FakeFriendsRepository()
    : super(callFunction: (name, payload) async => throw UnimplementedError(name));

  final calls = <String>[];
  Friend? found;
  FriendshipStatus sendResult = FriendshipStatus.pending;
  Object? acceptError;

  @override
  Stream<List<Friendship>> watchFriendships() => throw UnimplementedError('use o stream do teste');

  @override
  Future<Friend?> findByUsername(String raw) async {
    calls.add('findByUsername:$raw');
    return found;
  }

  @override
  Future<FriendshipStatus> sendFriendRequest(String username) async {
    calls.add('sendFriendRequest:$username');
    return sendResult;
  }

  @override
  Future<void> acceptFriendRequest(String friendUid) async {
    calls.add('acceptFriendRequest:$friendUid');
    if (acceptError != null) throw acceptError!;
  }

  @override
  Future<void> removeFriend(String friendUid) async {
    calls.add('removeFriend:$friendUid');
  }
}

const _rafa = Friend(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa');
const _bruno = Friend(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima');
const _diego = Friend(uid: 'diego', name: 'Diego Souza', username: 'diego.souza');
const _leo = Friend(uid: 'leo', name: 'Leo Martins', username: 'leo.martins');

Friendship _accepted(Friend other) => Friendship(
  id: '${_me}_${other.uid}',
  status: FriendshipStatus.accepted,
  requestedBy: _me,
  requestedTo: other.uid,
  other: other,
);

Friendship _incoming(Friend other) => Friendship(
  id: '${_me}_${other.uid}',
  status: FriendshipStatus.pending,
  requestedBy: other.uid,
  requestedTo: _me,
  other: other,
);

Friendship _outgoing(Friend other) => Friendship(
  id: '${_me}_${other.uid}',
  status: FriendshipStatus.pending,
  requestedBy: _me,
  requestedTo: other.uid,
  other: other,
);

Session _session(String id, String name, List<String> participants, {String? mergedInto}) =>
    Session(
      id: id,
      name: name,
      ownerId: _me,
      participantIds: participants,
      participants: [for (final p in participants) SessionParticipant(uid: p, name: p)],
      participantCount: participants.length,
      startedAt: DateTime(2026, 9, 11, 19, 30),
      duration: const Duration(hours: 1),
      highlightCount: 3,
      mergedInto: mergedInto,
    );

final _sessions = [
  _session('s1', 'Pelada de quinta', [_me, 'rafa', 'bruno']),
  _session('s2', 'Vôlei de domingo', [_me, 'rafa']),
  _session('s3', 'Juntada', [_me, 'rafa'], mergedInto: 's1'),
  _session('s4', 'Sem o Rafa', [_me, 'bruno']),
];

Widget _app(Widget home, {Brightness brightness = Brightness.dark, double textScale = 1}) {
  return MaterialApp(
    theme: clippoTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

Widget _screen(
  _FakeFriendsRepository repo, {
  Stream<List<Friendship>>? friendships,
  Stream<SessionsSnapshot>? sessions,
  ValueChanged<Session>? onOpenSession,
}) => FriendsScreen(
  repository: repo,
  myUid: _me,
  friendships:
      friendships ??
      Stream.value([_accepted(_rafa), _accepted(_bruno), _incoming(_diego), _outgoing(_leo)]),
  sessions: sessions ?? Stream.value(SessionsSnapshot(sessions: _sessions, fromCache: false)),
  onOpenSession: onOpenSession,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('separa amigos, convites recebidos e pedidos enviados vindos do stream', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(_screen(_FakeFriendsRepository())));
    await tester.pumpAndSettle();

    expect(find.text('SEUS\nAMIGOS.'), findsOneWidget);
    expect(find.text('Convites recebidos'), findsOneWidget);
    expect(find.text('@diego.souza · quer jogar com você'), findsOneWidget);
    expect(find.text('Pedidos enviados'), findsOneWidget);
    expect(find.text('@leo.martins · esperando aceitar'), findsOneWidget);
    // R16: conta as sessões dos dois, sem as juntadas a outra.
    expect(find.text('@rafa.costa · 2 sessões juntos'), findsOneWidget);
    expect(find.text('@bruno.lima · 2 sessões juntos'), findsOneWidget);
    // Não existe mais a aba de entrar em sessão por código ou link.
    expect(find.text('Entrar em uma sessão'), findsNothing);
    expect(find.bySemanticsLabel('Sessões'), findsNothing);
  });

  testWidgets('mostra carregando e depois a lista vazia', (tester) async {
    _phone(tester);
    final controller = StreamController<List<Friendship>>();
    addTearDown(controller.close);
    await tester.pumpWidget(
      _app(_screen(_FakeFriendsRepository(), friendships: controller.stream)),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Carregando seus amigos'), findsOneWidget);

    controller.add(const []);
    await tester.pumpAndSettle();
    expect(find.text('Adicione quem joga com você'), findsOneWidget);
    expect(find.text('Convites recebidos'), findsNothing);
  });

  testWidgets('erro do stream mostra a mensagem do FriendsFailure e tenta de novo', (tester) async {
    _phone(tester);
    var attempts = 0;
    Stream<List<Friendship>> friendships() async* {
      attempts++;
      if (attempts == 1) {
        throw const FriendsFailure('Sem internet. Seus amigos aparecem assim que você conectar.');
      }
      yield [_accepted(_rafa)];
    }

    // Um stream que refaz a leitura a cada assinatura, como o Firestore.
    final stream = Stream<List<Friendship>>.multi((c) {
      friendships().listen(c.add, onError: c.addError, onDone: c.close);
    });

    await tester.pumpWidget(_app(_screen(_FakeFriendsRepository(), friendships: stream)));
    await tester.pumpAndSettle();
    expect(
      find.text('Sem internet. Seus amigos aparecem assim que você conectar.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Rafa Costa'), findsOneWidget);
  });

  testWidgets('aceitar, recusar e cancelar chamam o repositório', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Aceitar convite de Diego Souza'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['acceptFriendRequest:diego']);
    expect(find.text('Agora você e Diego são amigos.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Recusar convite de Diego Souza'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'removeFriend:diego');

    await tester.tap(find.bySemanticsLabel('Cancelar pedido para Leo Martins'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'removeFriend:leo');
  });

  testWidgets('erro ao aceitar aparece com a mensagem do repositório', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository()
      ..acceptError = const FriendsFailure('Esse pedido não existe mais.');
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Aceitar convite de Diego Souza'));
    await tester.pumpAndSettle();
    expect(find.text('Esse pedido não existe mais.'), findsOneWidget);
  });

  testWidgets('a busca filtra só a lista de amigos carregada', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'brun');
    await tester.pumpAndSettle();
    expect(find.text('Bruno Lima'), findsOneWidget);
    expect(find.text('Rafa Costa'), findsNothing);
    expect(find.text('Convites recebidos'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '@zeca');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum amigo com "@zeca"'), findsOneWidget);
    expect(find.text('Procurar @zeca'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('@ inválido mostra o erro embaixo do campo sem chamar nada', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Convidar amigo'));
    await tester.pumpAndSettle();
    expect(find.text('ADICIONAR\nAMIGO.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a b');
    await tester.tap(find.text('Procurar'));
    await tester.pumpAndSettle();
    expect(find.text('O nome de usuário precisa ter de 3 a 20 caracteres.'), findsNothing);
    expect(find.text('Use só letras sem acento, números, "_" e ".".'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.tap(find.text('Procurar'));
    await tester.pumpAndSettle();
    expect(find.text('O nome de usuário precisa ter de 3 a 20 caracteres.'), findsOneWidget);
    expect(repo.calls, isEmpty);
  });

  testWidgets('procura pelo @, adiciona e avisa quando já viram amigos', (tester) async {
    _phone(tester);
    const pedro = Friend(uid: 'pedro', name: 'Pedro Rocha', username: 'pedro.rocha');
    final repo = _FakeFriendsRepository()
      ..found = pedro
      ..sendResult = FriendshipStatus.accepted;
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Convidar amigo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '@Pedro.Rocha');
    await tester.tap(find.text('Procurar'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['findByUsername:@Pedro.Rocha']);
    expect(find.text('Pedro Rocha'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Adicionar amigo Pedro Rocha'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'sendFriendRequest:pedro.rocha');
    expect(find.text('Agora você e Pedro são amigos.'), findsOneWidget);
  });

  testWidgets('@ que ninguém usa diz isso e oferece o link para baixar', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Convidar amigo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ninguem');
    await tester.tap(find.text('Procurar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ninguém usa @ninguem no Clippo. Confira o @ ou mande o link abaixo.'),
      findsOneWidget,
    );
    expect(find.text('https://clippo.app/baixar'), findsOneWidget);
  });

  testWidgets('remover pelo menu ⋮ pede confirmação e chama removeFriend', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    await tester.pumpWidget(_app(_screen(repo)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.bySemanticsLabel('Opções de Rafa Costa'));
    await tester.tap(find.bySemanticsLabel('Opções de Rafa Costa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover dos amigos'));
    await tester.pumpAndSettle();
    expect(find.text('Remover Rafa dos amigos?'), findsOneWidget);

    await tester.tap(find.text('Manter amigo'));
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.ensureVisible(find.bySemanticsLabel('Opções de Rafa Costa'));
    await tester.tap(find.bySemanticsLabel('Opções de Rafa Costa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover dos amigos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['removeFriend:rafa']);
  });

  testWidgets('perfil do amigo lista as sessões juntos e abre a Sessão', (tester) async {
    _phone(tester);
    final repo = _FakeFriendsRepository();
    Session? opened;
    await tester.pumpWidget(_app(_screen(repo, onOpenSession: (s) => opened = s)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Rafa Costa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rafa Costa'));
    await tester.pumpAndSettle();

    expect(find.text('PERFIL DE\nRAFA.'), findsOneWidget);
    expect(find.text('Sessões juntos'), findsOneWidget);
    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('Vôlei de domingo'), findsOneWidget);
    expect(find.text('Juntada'), findsNothing);
    expect(find.text('Sem o Rafa'), findsNothing);

    await tester.ensureVisible(find.text('Ver highlights').first);
    await tester.tap(find.text('Ver highlights').first);
    await tester.pumpAndSettle();
    expect(opened?.id, 's1');

    await tester.tap(find.text('Remover dos amigos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['removeFriend:rafa']);
    expect(find.text('SEUS\nAMIGOS.'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _app(_screen(_FakeFriendsRepository()), brightness: brightness, textScale: scale),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Rafa Costa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rafa Costa'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('sem login e sem stream injetado pede para entrar, sem tocar no Firebase', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app(const FriendsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Entre na sua conta para ver seus amigos.'), findsOneWidget);
  });
}
