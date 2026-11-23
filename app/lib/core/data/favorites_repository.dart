import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:clippo/core/data/favorite.dart';
import 'package:clippo/core/data/sessions_repository.dart' show CallableInvoker;
import 'package:clippo/core/firebase/firebase_setup.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Erro dos favoritos, com a frase pronta para a tela (nunca o código técnico).
class FavoritesFailure implements Exception {
  const FavoritesFailure(this.message, {this.code});

  final String message;

  /// Código do Firebase ou nome do campo inválido. Nunca aparece na interface.
  final String? code;

  factory FavoritesFailure.from(Object error) {
    if (error is FavoritesFailure) return error;
    if (error is! FirebaseException) return const FavoritesFailure('Algo deu errado.');
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
        return FavoritesFailure('Sem internet. Os favoritos aparecem assim que você conectar.', code: error.code);
      case 'permission-denied':
        return FavoritesFailure('Só os amigos veem os favoritos dessa pessoa.', code: error.code);
      case 'unauthenticated':
        return FavoritesFailure('Entre na sua conta para ver os favoritos.', code: error.code);
      case 'failed-precondition':
        return FavoritesFailure('Algo deu errado aqui do nosso lado. Avise o time do Clippo.', code: error.code);
      default:
        return FavoritesFailure('Algo deu errado.', code: error.code);
    }
  }

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Tudo o que o app lê e grava sobre favoritos (R18–R22) passa por aqui (regra 4 do AGENTS.md).
///
/// A leitura vem do Firestore, pelas regras (só quem favoritou e os amigos dele). A escrita passa
/// pelas Functions `favoriteHighlight`, `unfavoriteHighlight`, `likePost`, `addComment` e
/// `deleteComment`, que validam de novo no servidor (regra 0).
class FavoritesRepository {
  FavoritesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    CallableInvoker? callFunction,
    String Function()? newCommentId,
  })  : _firestore = (() => firestore ?? FirebaseFirestore.instance),
        _auth = (() => auth ?? FirebaseAuth.instance),
        _newCommentId = newCommentId ?? _randomId,
        _callFunction = (callFunction ??
            ((name, payload) async =>
                (await (functions ?? FirebaseFunctions.instanceFor(region: functionsRegion))
                        .httpsCallable(name)
                        .call<Map<String, dynamic>>(payload))
                    .data));

  /// Nome da coleção no Firestore. Igual ao de backend/firestore.rules.
  static const String collectionName = 'posts';

  final FirebaseFirestore Function() _firestore;
  final FirebaseAuth Function() _auth;
  final CallableInvoker _callFunction;
  final String Function() _newCommentId;

  /// O id do favorito: um por pessoa e lance (o mesmo `postIdFor` do servidor).
  static String postIdFor(String uid, String sessionId, String highlightId) => '${uid}__${sessionId}__$highlightId';

  CollectionReference<Map<String, dynamic>> get _posts => _firestore().collection(collectionName);

  String get _myUid {
    final uid = _auth().currentUser?.uid;
    if (uid == null) throw const FavoritesFailure('Entre na sua conta para ver os favoritos.');
    return uid;
  }

  /// Os favoritos de [ownerId], do mais recente para o mais antigo (o perfil). Só funciona para a
  /// própria pessoa e os amigos dela: para os outros, as regras recusam.
  Stream<List<FavoritePost>> watchPostsOf(String ownerId) => _posts
      .where('ownerId', isEqualTo: ownerId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map(FavoritePost.fromDocument).toList(growable: false));

  /// Um favorito, ao vivo (contagens de curtidas e comentários). Nulo se sumiu.
  Stream<FavoritePost?> watchPost(String postId) =>
      _posts.doc(postId).snapshots().map((doc) => doc.exists ? FavoritePost.fromDocument(doc) : null);

  /// O MEU favorito deste lance, se eu favoritei (nulo se não). É o que o Player mostra no coração.
  Stream<FavoritePost?> watchMyFavorite({required String sessionId, required String highlightId}) =>
      watchPost(postIdFor(_myUid, sessionId, highlightId));

  /// Se eu curti o favorito.
  Stream<bool> watchLiked(String postId) =>
      _posts.doc(postId).collection('likes').doc(_myUid).snapshots().map((doc) => doc.exists);

  /// Os comentários do favorito, do mais antigo para o mais novo.
  Stream<List<FavoriteComment>> watchComments(String postId) => _posts
      .doc(postId)
      .collection('comments')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => snap.docs.map((d) => FavoriteComment.fromMap(d.id, d.data())).toList(growable: false));

  /// Favorita um lance (R18). Favoritar de novo não duplica. Devolve o id do favorito.
  Future<String> favorite({required String sessionId, required String highlightId}) async {
    _check('sessionId', validateHighlightRef(sessionId));
    _check('highlightId', validateHighlightRef(highlightId));
    final data = await _call('favoriteHighlight', {'sessionId': sessionId, 'highlightId': highlightId},
        fallback: 'Não foi possível favoritar o lance. Tente de novo.');
    return data['postId'] as String? ?? '';
  }

  /// Desfaz o favorito (R21): somem as curtidas e os comentários. Desfazer de novo não é erro.
  Future<void> unfavorite({required String sessionId, required String highlightId}) async {
    _check('sessionId', validateHighlightRef(sessionId));
    _check('highlightId', validateHighlightRef(highlightId));
    await _call('unfavoriteHighlight', {'sessionId': sessionId, 'highlightId': highlightId},
        fallback: 'Não foi possível desfavoritar o lance. Tente de novo.');
  }

  /// Curte ou descurte. Devolve quantas curtidas o favorito tem agora.
  Future<int> setLiked(String postId, {required bool liked}) async {
    _check('postId', validatePostId(postId));
    final data = await _call('likePost', {'postId': postId, 'liked': liked},
        fallback: 'Não deu para curtir agora. Tente de novo.');
    return (data['likeCount'] as num?)?.toInt() ?? 0;
  }

  /// Comenta (R22). Valida antes, com as mesmas regras do servidor. O id do comentário nasce
  /// aqui, para repetir a chamada (a conexão caiu na resposta) não duplicar.
  Future<String> addComment(String postId, String text) async {
    _check('postId', validatePostId(postId));
    _check('text', validateComment(text));
    final commentId = _newCommentId();
    await _call('addComment', {'postId': postId, 'commentId': commentId, 'text': normalizeComment(text)},
        fallback: 'Não foi possível comentar. Tente de novo.');
    return commentId;
  }

  /// Apaga um comentário: o autor apaga o seu; quem favoritou apaga qualquer um (R22).
  Future<void> deleteComment(String postId, String commentId) async {
    _check('postId', validatePostId(postId));
    _check('commentId', validateCommentId(commentId));
    await _call('deleteComment', {'postId': postId, 'commentId': commentId},
        fallback: 'Não foi possível apagar o comentário. Tente de novo.');
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> payload, {required String fallback}) async {
    try {
      return await _callFunction(name, payload);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      throw FavoritesFailure(e.message ?? fallback, code: field ?? e.code);
    } on FirebaseException catch (e) {
      throw FavoritesFailure.from(e);
    }
  }

  static void _check(String field, String? error) {
    if (error != null) throw FavoritesFailure(error, code: field);
  }

  static final Random _random = Random.secure();
  static const String _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  static String _randomId() => List.generate(20, (_) => _alphabet[_random.nextInt(_alphabet.length)]).join();
}

FavoritesRepository? _favoritesRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
FavoritesRepository get favoritesRepository => _favoritesRepository ??= FavoritesRepository();
