import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:clippo/core/data/favorite.dart';
import 'package:clippo/core/data/favorites_repository.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_favorites_section.dart';
import 'package:clippo/features/home/screens/player_screen.dart';

// Favoritos (R18–R22) sem Firebase: o repositório é trocado por um que guarda as chamadas e
// devolve streams controlados pelo teste.

const _session = 'quinta-0001';

Highlight _highlight(String id, {HighlightStatus status = HighlightStatus.uploaded}) => Highlight(
      id: id,
      title: 'Golaço',
      offset: const Duration(minutes: 4),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 34),
      createdBy: 'alice',
      videoPath: 'sessions/$_session/highlights/$id/video.mp4',
      status: status,
    );

FavoritePost _post({String owner = 'leo', int likes = 2, int comments = 0}) => FavoritePost(
      id: '${owner}__${_session}__lance-0001',
      ownerId: owner,
      ownerName: 'Leo Dias',
      ownerUsername: 'leo',
      sessionId: _session,
      highlightId: 'lance-0001',
      title: 'Golaço',
      duration: const Duration(seconds: 30),
      playedAt: DateTime(2026, 9, 11),
      videoPath: 'posts/${owner}__${_session}__lance-0001/video.mp4',
      likeCount: likes,
      commentCount: comments,
    );

class _FakeFavorites extends FavoritesRepository {
  _FakeFavorites() : super(callFunction: (name, payload) async => const {}, newCommentId: () => 'c-000001');

  final calls = <String>[];
  final mine = StreamController<FavoritePost?>.broadcast();
  final post = StreamController<FavoritePost?>.broadcast();
  final liked = StreamController<bool>.broadcast();
  final comments = StreamController<List<FavoriteComment>>.broadcast();
  int likeCountAfter = 3;

  @override
  Stream<FavoritePost?> watchMyFavorite({required String sessionId, required String highlightId}) {
    calls.add('watchMine $sessionId/$highlightId');
    return mine.stream;
  }

  @override
  Stream<FavoritePost?> watchPost(String postId) => post.stream;

  @override
  Stream<bool> watchLiked(String postId) => liked.stream;

  @override
  Stream<List<FavoriteComment>> watchComments(String postId) => comments.stream;

  @override
  Future<String> favorite({required String sessionId, required String highlightId}) async {
    calls.add('favorite $sessionId/$highlightId');
    return 'me__${sessionId}__$highlightId';
  }

  @override
  Future<void> unfavorite({required String sessionId, required String highlightId}) async {
    calls.add('unfavorite $sessionId/$highlightId');
  }

  @override
  Future<int> setLiked(String postId, {required bool liked}) async {
    calls.add('like $liked');
    return likeCountAfter;
  }

  @override
  Future<String> addComment(String postId, String text) async {
    calls.add('comment $text');
    return 'c-000001';
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    calls.add('delete $commentId');
  }
}

/// Player aberto e tocando, sem o plugin de vídeo.
class _Controller extends VideoPlayerController {
  _Controller() : super.networkUrl(Uri.parse('https://exemplo.invalid/video.mp4'));

  @override
  Future<void> initialize() async {
    value = const VideoPlayerValue(duration: Duration(seconds: 30), size: Size(720, 1280), isInitialized: true);
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}
}

Widget _app(Widget home) => MaterialApp(theme: clippoTheme(Brightness.dark), home: home);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<HighlightVideoStream> _stream(String path) async =>
    HighlightVideoStream(url: Uri.parse('https://exemplo.invalid/v.mp4'), headers: const {});

void main() {
  group('Player de uma sessão: favoritar (R18)', () {
    Future<_FakeFavorites> open(WidgetTester tester, Highlight highlight) async {
      _phone(tester);
      final favorites = _FakeFavorites();
      await tester.pumpWidget(_app(PlayerScreen(
        sessionName: 'Pelada de quinta',
        sessionId: _session,
        highlights: [highlight],
        favorites: favorites,
        currentUserId: 'me',
        streamVideo: _stream,
        streamControllerFactory: (_) => _Controller(),
      )));
      await tester.pump();
      await tester.pump();
      return favorites;
    }

    testWidgets('o coração favorita o lance que já subiu', (tester) async {
      final favorites = await open(tester, _highlight('lance-0001'));
      expect(favorites.calls, ['watchMine $_session/lance-0001']);

      await tester.tap(find.bySemanticsLabel('Favoritar'));
      await tester.pump();
      expect(favorites.calls.last, 'favorite $_session/lance-0001');
      expect(find.text('Lance favoritado. Seus amigos veem no seu perfil.'), findsOneWidget);

      // O servidor confirma: o coração enche e vira "Desfavoritar".
      favorites.mine.add(_post(owner: 'me'));
      await tester.pump();
      expect(find.bySemanticsLabel('Desfavoritar'), findsOneWidget);
    });

    testWidgets('desfavoritar com comentários pergunta antes', (tester) async {
      final favorites = await open(tester, _highlight('lance-0001'));
      favorites.mine.add(_post(owner: 'me', comments: 2));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Desfavoritar'));
      await tester.pumpAndSettle();
      expect(find.text('Desfavoritar o lance?'), findsOneWidget);
      await tester.tap(find.text('Manter'));
      await tester.pumpAndSettle();
      expect(favorites.calls.where((c) => c.startsWith('unfavorite')), isEmpty);
      await tester.tap(find.bySemanticsLabel('Desfavoritar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desfavoritar').last);
      await tester.pumpAndSettle();
      expect(favorites.calls.last, 'unfavorite $_session/lance-0001');
    });

    testWidgets('lance que ainda está subindo não dá para favoritar', (tester) async {
      _phone(tester);
      final favorites = _FakeFavorites();
      await tester.pumpWidget(_app(PlayerScreen(
        sessionId: _session,
        highlights: [_highlight('lance-0002', status: HighlightStatus.pending)],
        favorites: favorites,
        currentUserId: 'me',
        loadVideo: (_) => Completer<Never>().future,
      )));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Favoritar'), warnIfMissed: false);
      await tester.pump();
      expect(favorites.calls.where((c) => c.startsWith('favorite')), isEmpty);
    });

    testWidgets('sem a sessão (ou sem login), o coração não aparece', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(PlayerScreen(
        highlights: [_highlight('lance-0001')],
        loadVideo: (_) => Completer<Never>().future,
      )));
      await tester.pump();
      expect(find.bySemanticsLabel('Favoritar'), findsNothing);
      expect(find.bySemanticsLabel('Baixar'), findsOneWidget);
    });
  });

  group('Player de um favorito (R19, R20)', () {
    Future<_FakeFavorites> open(WidgetTester tester, FavoritePost post, {String viewer = 'bia'}) async {
      _phone(tester);
      final favorites = _FakeFavorites();
      await tester.pumpWidget(_app(PlayerScreen(
        sessionName: 'Favorito de ${post.ownerFirstName}',
        highlights: [post.toHighlight()],
        favorite: post,
        favorites: favorites,
        currentUserId: viewer,
        streamVideo: _stream,
        streamControllerFactory: (_) => _Controller(),
      )));
      await tester.pump();
      await tester.pump();
      return favorites;
    }

    testWidgets('mostra quem favoritou e a data, sem a sessão nem o contador', (tester) async {
      await open(tester, _post());
      expect(find.text('Favorito de Leo'), findsOneWidget);
      expect(find.text('11 set 2026 · 2 curtidas · nenhum comentário'), findsOneWidget);
      expect(find.text('1 de 1'), findsNothing);
      expect(find.text('Pelada de quinta'), findsNothing);
    });

    testWidgets('a amiga curte na hora e o servidor confirma a contagem', (tester) async {
      final favorites = await open(tester, _post());
      await tester.tap(find.bySemanticsLabel('Curtir'));
      await tester.pump();
      expect(find.bySemanticsLabel('Descurtir'), findsOneWidget);
      expect(favorites.calls.last, 'like true');
      expect(find.text('11 set 2026 · 3 curtidas · nenhum comentário'), findsOneWidget);
    });

    testWidgets('quem não favoritou não baixa nem compartilha; quem favoritou, sim', (tester) async {
      await open(tester, _post());
      expect(find.bySemanticsLabel('Baixar'), findsNothing);
      expect(find.bySemanticsLabel('Compartilhar'), findsNothing);

      await open(tester, _post(), viewer: 'leo');
      expect(find.bySemanticsLabel('Baixar'), findsOneWidget);
    });

    testWidgets('comentários: valida embaixo do campo, envia e só o autor ou o dono apagam', (tester) async {
      final favorites = await open(tester, _post());
      await tester.tap(find.bySemanticsLabel('Comentários (0)'));
      // O "carregando" da lista gira até chegar o primeiro pedaço: sem pumpAndSettle aqui.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      favorites.comments.add(const [
        FavoriteComment(id: 'c-000009', authorId: 'bia', authorName: 'Bia Prado', text: 'Que golaço!'),
        FavoriteComment(id: 'c-000010', authorId: 'caio', authorName: 'Caio Nunes', text: 'Boa'),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Que golaço!'), findsOneWidget);
      // A bia apaga só o dela (o favorito é do leo).
      expect(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Apagar comentário'),
        findsOneWidget,
      );

      await tester.tap(find.text('Comentar'));
      await tester.pump();
      expect(find.text('Escreva um comentário.'), findsOneWidget);
      expect(favorites.calls.where((c) => c.startsWith('comment')), isEmpty);

      await tester.enterText(find.byType(EditableText), '  Top demais  ');
      await tester.tap(find.text('Comentar'));
      await tester.pump();
      expect(favorites.calls.last, 'comment   Top demais  ');
    });
  });

  group('ClippoFavoritesSection', () {
    testWidgets('lista os favoritos com a data e as contagens; tocar abre', (tester) async {
      FavoritePost? opened;
      await tester.pumpWidget(_app(Scaffold(
        body: SingleChildScrollView(
          child: ClippoFavoritesSection(
            ownerId: 'leo',
            posts: Stream.value([_post(likes: 1, comments: 3)]),
            onOpen: (p) => opened = p,
          ),
        ),
      )));
      await tester.pump();
      expect(find.text('Favoritos'), findsOneWidget);
      expect(find.text('11 set 2026 · 1 curtida · 3 comentários'), findsOneWidget);
      await tester.tap(find.text('Golaço'));
      expect(opened?.id, _post().id);
    });

    testWidgets('sem favoritos, mostra a frase de vazio', (tester) async {
      await tester.pumpWidget(_app(Scaffold(
        body: ClippoFavoritesSection(
          ownerId: 'leo',
          posts: Stream.value(const []),
          emptyText: 'Leo ainda não favoritou nenhum lance.',
          onOpen: (_) {},
        ),
      )));
      await tester.pump();
      expect(find.text('Leo ainda não favoritou nenhum lance.'), findsOneWidget);
    });
  });

  group('FavoritesRepository valida antes de chamar a Function (regra 0)', () {
    test('comentário vazio não chama o servidor', () async {
      final calls = <String>[];
      final repo = FavoritesRepository(callFunction: (name, payload) async {
        calls.add(name);
        return const {};
      });
      await expectLater(
        repo.addComment('leo__quinta-0001__lance-0001', '   '),
        throwsA(isA<FavoritesFailure>().having((f) => f.code, 'code', 'text')),
      );
      expect(calls, isEmpty);
    });

    test('envia o comentário aparado, com o id gerado no app', () async {
      Map<String, dynamic>? sent;
      final repo = FavoritesRepository(
        newCommentId: () => 'c-abcdef',
        callFunction: (name, payload) async {
          sent = {'name': name, ...payload};
          return const {};
        },
      );
      expect(await repo.addComment('leo__quinta-0001__lance-0001', '  Top  '), 'c-abcdef');
      expect(sent, {'name': 'addComment', 'postId': 'leo__quinta-0001__lance-0001', 'commentId': 'c-abcdef', 'text': 'Top'});
    });

    test('favoritar com id fora do formato não chama o servidor', () async {
      final calls = <String>[];
      final repo = FavoritesRepository(callFunction: (name, payload) async {
        calls.add(name);
        return const {};
      });
      await expectLater(repo.favorite(sessionId: 'x', highlightId: 'lance-0001'), throwsA(isA<FavoritesFailure>()));
      expect(calls, isEmpty);
      expect(await repo.favorite(sessionId: _session, highlightId: 'lance-0001'), '');
      expect(calls, ['favoriteHighlight']);
    });

    test('o id do favorito é o mesmo do servidor', () {
      expect(FavoritesRepository.postIdFor('alice', 'quinta01', 'lance01'), 'alice__quinta01__lance01');
    });
  });
}
