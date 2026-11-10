import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart' show CallableInvoker;
import 'package:clippo/core/firebase/firebase_setup.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Erro ao ler ou mexer nos amigos, com a mensagem pronta para a tela.
class FriendsFailure implements Exception {
  const FriendsFailure(this.message, {this.code});

  /// O que a pessoa lê.
  final String message;

  /// Código do Firebase ou nome do campo inválido. Nunca aparece na interface.
  final String? code;

  factory FriendsFailure.from(Object error) {
    if (error is FriendsFailure) return error;
    if (error is! FirebaseException) return const FriendsFailure('Algo deu errado.');
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
        return FriendsFailure('Sem internet. Seus amigos aparecem assim que você conectar.',
            code: error.code);
      case 'unauthenticated':
      case 'permission-denied':
        return FriendsFailure('Entre de novo na sua conta para ver seus amigos.', code: error.code);
      default:
        return FriendsFailure('Algo deu errado.', code: error.code);
    }
  }

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// Tudo o que o app lê e grava sobre amigos passa por aqui (D16 em
/// docs/arquitetura.md › Amigos).
///
/// A leitura vem do Firestore (`friendships/`, só as duas pessoas leem); a escrita
/// passa pelas Functions `sendFriendRequest`, `acceptFriendRequest` e `removeFriend`.
/// A busca é por @ EXATO: ninguém lista `users/` nem `usernames/`.
class FriendsRepository {
  FriendsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    CallableInvoker? callFunction,
  })  : _firestore = (() => firestore ?? FirebaseFirestore.instance),
        _auth = (() => auth ?? FirebaseAuth.instance),
        _callFunction = (callFunction ??
            ((name, payload) async =>
                (await (functions ?? FirebaseFunctions.instanceFor(region: functionsRegion))
                        .httpsCallable(name)
                        .call<Map<String, dynamic>>(payload))
                    .data));

  /// Nome da coleção no Firestore. Igual ao de backend/firestore.rules.
  static const String collectionName = 'friendships';

  final FirebaseFirestore Function() _firestore;
  final FirebaseAuth Function() _auth;
  final CallableInvoker _callFunction;

  String _uid() {
    final uid = _auth().currentUser?.uid;
    if (uid == null) throw const FriendsFailure('Entre na sua conta para ver seus amigos.');
    return uid;
  }

  /// Todas as minhas amizades e pedidos (aceitos e esperando), em tempo real.
  ///
  /// O filtro `uids` contém eu NÃO é opcional: as Security Rules recusam a consulta
  /// inteira sem ele. A tela separa amigos e pedidos com [Friendship.isAccepted],
  /// [Friendship.isIncomingFor] e [Friendship.isOutgoingFor].
  Stream<List<Friendship>> watchFriendships() {
    final String uid;
    try {
      uid = _uid();
    } on FriendsFailure catch (e) {
      return Stream<List<Friendship>>.error(e);
    }
    return _firestore()
        .collection(collectionName)
        .where('uids', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Friendship.fromDocument(doc, myUid: uid))
            .toList(growable: false))
        .handleError((Object error) {
      throw FriendsFailure.from(error);
    });
  }

  /// Procura alguém pelo @ exato (com ou sem "@"). Nulo quando ninguém usa esse @.
  Future<Friend?> findByUsername(String raw) async {
    final error = validateUsername(raw);
    if (error != null) throw FriendsFailure(error, code: 'username');
    final username = normalizeUsername(raw);
    try {
      final lock = await _firestore().doc('usernames/$username').get();
      final uid = lock.data()?['uid'] as String?;
      if (uid == null) return null;
      final profile = await _firestore().doc('users/$uid').get();
      if (!profile.exists) return null;
      return Friend.fromMap(uid, profile.data() ?? const {});
    } on FirebaseException catch (e) {
      throw FriendsFailure.from(e);
    }
  }

  /// Manda o pedido de amizade pelo @. Se a outra pessoa já tinha me pedido, a amizade
  /// é aceita na hora; devolve a situação final.
  Future<FriendshipStatus> sendFriendRequest(String username) async {
    final error = validateUsername(username);
    if (error != null) throw FriendsFailure(error, code: 'username');
    final data = await _call('sendFriendRequest', {'username': normalizeUsername(username)});
    return data['status'] == 'accepted' ? FriendshipStatus.accepted : FriendshipStatus.pending;
  }

  /// Aceita o pedido que [friendUid] me mandou (R15).
  Future<void> acceptFriendRequest(String friendUid) async {
    _checkUid(friendUid);
    await _call('acceptFriendRequest', {'uid': friendUid});
  }

  /// Cancela o pedido que mandei, recusa o que recebi ou desfaz a amizade.
  Future<void> removeFriend(String friendUid) async {
    _checkUid(friendUid);
    await _call('removeFriend', {'uid': friendUid});
  }

  /// "X sessões juntos" (R16), contado a partir das sessões que a Início já leu.
  ///
  /// O Firestore não filtra duas vezes por `array-contains`; por isso a conta é no
  /// aparelho (docs/arquitetura.md › Amigos).
  static int sessionsTogether(String myUid, String friendUid, List<Session> mySessions) =>
      mySessions.where((s) => !s.isMerged && s.includesBoth(myUid, friendUid)).length;

  static void _checkUid(String uid) {
    final error = validateUid(uid);
    if (error != null) throw FriendsFailure(error, code: 'uid');
  }

  Future<Map<String, dynamic>> _call(String name, Map<String, dynamic> payload) async {
    try {
      return await _callFunction(name, payload);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      throw FriendsFailure(e.message ?? 'Algo deu errado. Tente de novo.', code: field ?? e.code);
    } on FirebaseException catch (e) {
      throw FriendsFailure.from(e);
    }
  }
}

FriendsRepository? _friendsRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
/// Provisório até a área de front-end escolher o gerenciamento de estado.
FriendsRepository get friendsRepository => _friendsRepository ??= FriendsRepository();
