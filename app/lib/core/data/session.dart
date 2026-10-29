import 'package:cloud_firestore/cloud_firestore.dart';

/// Onde a sessão foi jogada. O rótulo é o que aparece na tela; as coordenadas
/// vêm do GPS quando o aparelho sugeriu o local (produto.md › 4.5, estado D).
class SessionLocation {
  const SessionLocation({required this.label, this.latitude, this.longitude});

  SessionLocation.fromMap(Map<String, dynamic> data)
      : label = data['label'] as String? ?? '',
        latitude = (data['lat'] as num?)?.toDouble(),
        longitude = (data['lng'] as num?)?.toDouble();

  final String label;
  final double? latitude;
  final double? longitude;
}

/// Um participante como ele aparece na lista da Início: só o necessário para o avatar.
///
/// Vem da cópia `participantsPreview` guardada na própria sessão, não de `users/`:
/// sem ela, desenhar a lista custaria uma leitura por participante de cada sessão.
/// Em troca, quem trocou o nome ou a foto continua aparecendo com o antigo aqui —
/// a tela Sessão lê os perfis de verdade.
class SessionParticipant {
  const SessionParticipant({required this.uid, required this.name, this.photoUrl});

  SessionParticipant.fromMap(Map<String, dynamic> data)
      : uid = data['uid'] as String? ?? '',
        name = data['name'] as String? ?? '',
        photoUrl = data['photoUrl'] as String?;

  final String uid;
  final String name;
  final String? photoUrl;

  /// Primeiro nome, que é como os chips e as legendas chamam a pessoa ("Com Rafa").
  String get firstName => name.split(' ').first;
}

/// Uma sessão: um jogo gravado, com seus participantes e seus highlights.
/// Espelha o documento `sessions/{sessionId}` descrito em
/// docs/arquitetura.md › Modelo de dados.
///
/// A leitura é tolerante de propósito: campo faltando vira valor neutro em vez de
/// derrubar a lista inteira. Uma sessão torta aparece incompleta na Início; as
/// outras continuam aparecendo.
class Session {
  const Session({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.participantIds,
    required this.participants,
    required this.participantCount,
    required this.startedAt,
    required this.duration,
    required this.highlightCount,
    this.endedAt,
    this.location,
  });

  factory Session.fromMap(String id, Map<String, dynamic> data) {
    final participants = (data['participantsPreview'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SessionParticipant.fromMap)
        .toList(growable: false);
    final participantIds = (data['participantIds'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false);
    final location = data['location'];

    return Session(
      id: id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      participantIds: participantIds,
      participants: participants,
      // O contador é quem sabe o total; a cópia guarda só os primeiros.
      participantCount: (data['participantCount'] as num?)?.toInt() ?? participantIds.length,
      startedAt: _dateFrom(data['startedAt']) ?? _unknownDate,
      endedAt: _dateFrom(data['endedAt']),
      duration: Duration(seconds: (data['durationSeconds'] as num?)?.toInt() ?? 0),
      location: location is Map<String, dynamic> ? SessionLocation.fromMap(location) : null,
      highlightCount: (data['highlightCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory Session.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Session.fromMap(doc.id, doc.data() ?? const {});

  /// ID do documento no Firestore.
  final String id;

  /// Nome da sessão, confirmado por quem gravou ("Pelada de quinta").
  final String name;

  /// Quem iniciou a gravação. É dono e também participante (R9).
  final String ownerId;

  /// Todos os participantes. É por este campo que a Início consulta.
  final List<String> participantIds;

  /// Os primeiros participantes, prontos para desenhar avatares.
  final List<SessionParticipant> participants;

  /// Total de participantes, incluindo os que não estão em [participants].
  final int participantCount;

  final DateTime startedAt;
  final DateTime? endedAt;
  final Duration duration;

  /// Nulo quando ninguém informou o local nem o GPS sugeriu um.
  final SessionLocation? location;

  /// Quantos lances foram salvos nesta sessão.
  final int highlightCount;

  /// Quem gravou é o dono (R9) e, hoje, o único que edita a sessão (R12 🟡).
  bool isOwnedBy(String uid) => uid == ownerId;

  /// Os avatares que cabem na lista, e quantos ficaram de fora ("+N").
  List<SessionParticipant> visibleParticipants({int max = 5}) =>
      participants.take(max).toList(growable: false);

  int hiddenParticipantCount({int max = 5}) {
    final hidden = participantCount - max;
    return hidden > 0 ? hidden : 0;
  }

  /// Sessão sem data vai para o fim da lista, não para o topo. Na prática o
  /// Firestore nem devolve um documento sem `startedAt` (é o campo da ordenação).
  static final DateTime _unknownDate = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
