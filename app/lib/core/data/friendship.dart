import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação de uma amizade (R15): pedido esperando aceite ou amizade aceita.
enum FriendshipStatus { pending, accepted }

/// Um amigo (ou quem mandou/recebeu um pedido), como aparece na tela Amigos.
///
/// Vem da cópia `profiles` guardada no próprio documento da amizade (D16), para a
/// lista não precisar de uma leitura de `users/` por amigo.
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    required this.username,
    this.photoUrl,
  });

  Friend.fromMap(this.uid, Map<String, dynamic> data)
      : name = data['name'] as String? ?? '',
        username = data['username'] as String? ?? '',
        photoUrl = data['photoUrl'] as String?;

  final String uid;
  final String name;
  final String username;
  final String? photoUrl;

  String get firstName => name.split(' ').first;
}

/// O documento `friendships/{uidA_uidB}` (docs/arquitetura.md › Amigos, D16), visto
/// do lado de quem está logado.
class Friendship {
  const Friendship({
    required this.id,
    required this.status,
    required this.requestedBy,
    required this.requestedTo,
    required this.other,
  });

  /// Monta a amizade do ponto de vista de [myUid]: [other] é sempre a outra pessoa.
  factory Friendship.fromMap(String id, Map<String, dynamic> data, {required String myUid}) {
    final uids = (data['uids'] as List<dynamic>? ?? const []).whereType<String>().toList();
    final otherUid = uids.firstWhere((uid) => uid != myUid, orElse: () => '');
    final profiles = data['profiles'] as Map<String, dynamic>? ?? const {};
    final otherProfile = profiles[otherUid];
    return Friendship(
      id: id,
      status: data['status'] == 'accepted' ? FriendshipStatus.accepted : FriendshipStatus.pending,
      requestedBy: data['requestedBy'] as String? ?? '',
      requestedTo: data['requestedTo'] as String? ?? '',
      other: Friend.fromMap(
        otherUid,
        otherProfile is Map<String, dynamic> ? otherProfile : const {},
      ),
    );
  }

  factory Friendship.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc, {required String myUid}) =>
      Friendship.fromMap(doc.id, doc.data() ?? const {}, myUid: myUid);

  final String id;
  final FriendshipStatus status;
  final String requestedBy;
  final String requestedTo;

  /// A outra pessoa da amizade.
  final Friend other;

  bool get isAccepted => status == FriendshipStatus.accepted;

  /// Pedido que chegou para mim e espera o meu aceite.
  bool isIncomingFor(String uid) => status == FriendshipStatus.pending && requestedTo == uid;

  /// Pedido que eu mandei e espera a outra pessoa.
  bool isOutgoingFor(String uid) => status == FriendshipStatus.pending && requestedBy == uid;
}
