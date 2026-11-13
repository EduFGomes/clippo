import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/firebase/firebase_setup.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Assinatura para interceptar chamadas de Cloud Functions nos testes sem precisar do Firebase.
typedef CallableInvoker = Future<Map<String, dynamic>> Function(
  String functionName,
  Map<String, dynamic> payload,
);

/// Erro ao ler ou gravar sessões, com a mensagem pronta para a tela.
///
/// A regra do projeto é nunca mostrar erro técnico: "Erro 503" e
/// "permission-denied" viram frases curtas que dizem o que fazer
/// (docs/design.md › 2. Voz e texto). O [code] fica só para quem for investigar
/// (ou para indicar qual campo do formulário falhou).
class SessionsFailure implements Exception {
  const SessionsFailure(this.message, {this.code});

  /// O que a pessoa lê.
  final String message;

  /// Código do Firebase ou nome do campo inválido. Nunca aparece na interface.
  final String? code;

  /// Traduz o que o Firestore jogou para uma frase que faz sentido na quadra.
  factory SessionsFailure.from(Object error) {
    if (error is SessionsFailure) return error;
    if (error is StateError) {
      return const SessionsFailure('Entre na sua conta para ver suas sessões.');
    }
    if (error is! FirebaseException) {
      return const SessionsFailure('Algo deu errado.');
    }
    switch (error.code) {
      case 'unavailable':
      case 'network-request-failed':
        return SessionsFailure(
          'Sem internet. Suas sessões aparecem assim que você conectar.',
          code: error.code,
        );
      case 'deadline-exceeded':
        return SessionsFailure('A conexão está lenta. Tente de novo.', code: error.code);
      case 'unauthenticated':
        return SessionsFailure(
          'Entre na sua conta para ver suas sessões.',
          code: error.code,
        );
      case 'permission-denied':
        return SessionsFailure(
          'Não foi possível abrir suas sessões. Entre de novo na sua conta.',
          code: error.code,
        );
      case 'resource-exhausted':
        return SessionsFailure(
          'O Clippo está cheio de gente agora. Tente de novo em instantes.',
          code: error.code,
        );
      case 'failed-precondition':
        // Consulta sem índice: é erro nosso, não da pessoa.
        return SessionsFailure(
          'Algo deu errado aqui do nosso lado. Avise o time do Clippo.',
          code: error.code,
        );
      default:
        return SessionsFailure('Algo deu errado.', code: error.code);
    }
  }

  @override
  String toString() => code == null ? message : '$message ($code)';
}

/// As sessões que chegaram, e de onde vieram.
class SessionsSnapshot {
  const SessionsSnapshot({required this.sessions, required this.fromCache});

  final List<Session> sessions;

  /// true quando os dados são do cache do aparelho, não do servidor.
  ///
  /// Importa muito para a tela: sem internet e sem nada guardado, o Firestore
  /// devolve uma lista **vazia do cache**. Sem este sinal, a Início diria
  /// "Nenhuma sessão ainda" para quem só está sem sinal na quadra.
  final bool fromCache;

  bool get isEmpty => sessions.isEmpty;
}

/// Os highlights de uma sessão que chegaram, e de onde vieram.
class HighlightsSnapshot {
  const HighlightsSnapshot({required this.highlights, required this.fromCache});

  final List<Highlight> highlights;

  /// true quando os dados vieram apenas do cache local do aparelho.
  final bool fromCache;

  bool get isEmpty => highlights.isEmpty;
}

/// Tudo o que o app lê e grava sobre sessões passa por aqui.
///
/// As telas não falam direto com o Firestore nem com as Functions (regra 4 do
/// AGENTS.md): chamam estes métodos. A leitura vem do Firestore; a escrita
/// passa pela Cloud Function `saveSession` (D15 em docs/arquitetura.md › Quem
/// grava sessões e highlights), mantendo as Security Rules fechadas para escrita.
class SessionsRepository {
  SessionsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    CallableInvoker? callFunction,
  })  : _firestore = (() => firestore ?? FirebaseFirestore.instance),
        _auth = (() => auth ?? FirebaseAuth.instance),
        _callFunction = (callFunction ??
            ((name, payload) async =>
                (await (functions ??
                            FirebaseFunctions.instanceFor(region: functionsRegion))
                        .httpsCallable(name)
                        .call<Map<String, dynamic>>(payload))
                    .data));

  /// Nome da coleção no Firestore. Igual ao de backend/firestore.rules.
  static const String collectionName = 'sessions';

  /// Subcoleção de lances dentro de cada sessão.
  static const String highlightsSubcollection = 'highlights';

  final FirebaseFirestore Function() _firestore;
  final FirebaseAuth Function() _auth;
  final CallableInvoker _callFunction;

  /// As sessões de que a pessoa logada participa, da mais recente para a mais
  /// antiga — é o que a Início lista (produto.md › 4.2).
  ///
  /// Emite de novo a cada mudança no servidor, então a sessão que outro
  /// participante acabou de salvar aparece sozinha, sem recarregar a tela.
  Stream<SessionsSnapshot> watchMySessions() {
    final uid = _auth().currentUser?.uid;
    if (uid == null) {
      // Não deveria acontecer: a Início só existe depois do login (AuthGate).
      return Stream<SessionsSnapshot>.error(
        const SessionsFailure('Entre na sua conta para ver suas sessões.'),
      );
    }
    return watchSessionsOf(uid);
  }

  /// As sessões de um participante.
  ///
  /// O filtro por `participantIds` NÃO é opcional: as Security Rules valem
  /// documento por documento, então uma consulta sem ele é recusada inteira ao
  /// encontrar a primeira sessão de outra pessoa. A ordenação precisa do índice
  /// composto de backend/firestore.indexes.json.
  Stream<SessionsSnapshot> watchSessionsOf(String uid) {
    return _firestore()
        .collection(collectionName)
        .where('participantIds', arrayContains: uid)
        .orderBy('startedAt', descending: true)
        // Com as mudanças de metadados: quando o servidor confirma o que já estava no cache, o
        // `fromCache` vira false e o "Sem internet" some. Sem isso, o aviso ficava preso.
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => SessionsSnapshot(
            // Sessão juntada a outra (D18) não aparece: os lances dela estão na principal.
            // O filtro é aqui, e não na consulta, para não precisar de índice novo nem
            // de reescrever as sessões antigas, que não têm o campo `mergedInto`.
            sessions: snapshot.docs
                .map(Session.fromDocument)
                .where((session) => !session.isMerged)
                .toList(growable: false),
            fromCache: snapshot.metadata.isFromCache,
          ),
        )
        .handleError((Object error) {
      throw SessionsFailure.from(error);
    });
  }

  /// Os highlights de uma sessão em ordem cronológica (produto.md › 4.3).
  Stream<HighlightsSnapshot> watchHighlightsOf(String sessionId) {
    return _firestore()
        .collection(collectionName)
        .doc(sessionId)
        .collection(highlightsSubcollection)
        .orderBy('offsetSeconds')
        // Mesmo motivo do watchSessionsOf: o "Sem internet" some quando o servidor confirma.
        .snapshots(includeMetadataChanges: true)
        .map(
          (snapshot) => HighlightsSnapshot(
            highlights: List<Highlight>.unmodifiable([
              for (var i = 0; i < snapshot.docs.length; i++)
                Highlight.fromDocument(snapshot.docs[i], index: i),
            ]),
            fromCache: snapshot.metadata.isFromCache,
          ),
        )
        .handleError((Object error) {
      throw SessionsFailure.from(error);
    });
  }

  /// Salva a sessão e os lances dela, no "Salvar sessão" (produto.md › 4.5, estado D).
  ///
  /// Chama a Cloud Function saveSession (D15): o app não grava sessão direto no
  /// Firestore. Devolve, por lance, o caminho onde o vídeo deve ser enviado no Storage.
  ///
  /// É seguro repetir: o [sessionId] e o id de cada lance nascem no aparelho, então
  /// chamar de novo depois de uma falha de rede não duplica nada — é assim que a fila
  /// offline (R13) funciona.
  Future<Map<String, String>> saveSession({
    required String sessionId,
    required String name,
    required DateTime startedAt,
    required DateTime endedAt,
    String? location,
    List<String> participantIds = const [],
    List<PendingHighlight> highlights = const [],
    DateTime? now,
  }) async {
    // Nada vai para o servidor sem passar pela validação (regra 0 do AGENTS.md).
    _check('sessionId', validateEntityId(sessionId));
    _check('name', validateSessionName(name));
    _check('location', validateLocation(location));
    _check('endedAt', validateSessionPeriod(startedAt, endedAt, now: now));
    _check('participantIds', validateParticipantIds(participantIds));

    if (highlights.length > highlightsMax) {
      throw const SessionsFailure(
        'Uma sessão pode ter até $highlightsMax lances.',
        code: 'highlights',
      );
    }

    final sessionDurationSeconds = endedAt.difference(startedAt).inSeconds;
    final seenHighlightIds = <String>{};
    for (final h in highlights) {
      _check('highlights', validateEntityId(h.highlightId));
      if (!seenHighlightIds.add(h.highlightId)) {
        throw const SessionsFailure(
          'Não foi possível salvar os lances.',
          code: 'highlights',
        );
      }
      _check(
        'highlights',
        validateHighlightOffset(
          h.offset.inSeconds,
          sessionDurationSeconds: sessionDurationSeconds,
        ),
      );
      _check('highlights', validateHighlightDuration(h.duration.inSeconds));
      _check('highlights', validateHighlightTitle(h.title));
    }

    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'name': normalizeSessionName(name),
      'startedAt': startedAt.toUtc().toIso8601String(),
      'endedAt': endedAt.toUtc().toIso8601String(),
      'location': normalizeLocation(location),
      'participantIds': normalizeParticipantIds(participantIds),
      'highlights': [
        for (var i = 0; i < highlights.length; i++)
          highlights[i].toJson(position: i + 1),
      ],
    };

    try {
      final data = await _callFunction('saveSession', payload);
      final paths = (data['videoPaths'] as Map?) ?? const {};
      return paths.map((key, value) => MapEntry(key as String, value as String));
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      throw SessionsFailure(
        e.message ?? 'Não foi possível salvar a sessão. Tente de novo.',
        code: field,
      );
    } on FirebaseException catch (e) {
      throw SessionsFailure.from(e);
    }
  }

  /// O dono muda nome, local e/ou participantes depois de salva (R12).
  ///
  /// Só vai o que não for nulo. [participantIds] é a lista inteira, nova (sem o dono,
  /// que entra sozinho); quem entra precisa ser amigo do dono (R10, conferido no servidor).
  Future<void> updateSession({
    required String sessionId,
    String? name,
    String? location,
    bool clearLocation = false,
    List<String>? participantIds,
    DateTime? startedAt,
    DateTime? endedAt,
    Iterable<Duration> highlightOffsets = const [],
    DateTime? now,
  }) async {
    _check('sessionId', validateEntityId(sessionId));
    if (name != null) _check('name', validateSessionName(name));
    if (location != null) _check('location', validateLocation(location));
    if (participantIds != null) {
      _check('participantIds', validateParticipantIds(participantIds));
    }
    // Data e horário vão juntos, com as regras do saveSession; os lances que a tela conhece
    // ([highlightOffsets]) precisam caber. O servidor confere de novo com os do banco.
    final period = startedAt != null || endedAt != null;
    if (period) {
      _check('endedAt', validateSessionPeriod(startedAt, endedAt, now: now));
      _check('endedAt', validatePeriodFitsHighlights(endedAt!.difference(startedAt!), highlightOffsets));
    }

    await _call('updateSession', {
      'sessionId': sessionId,
      if (name != null) 'name': normalizeSessionName(name),
      if (clearLocation) 'location': null else if (location != null) 'location': normalizeLocation(location),
      if (participantIds != null) 'participantIds': normalizeParticipantIds(participantIds),
      if (period) 'startedAt': startedAt!.toUtc().toIso8601String(),
      if (period) 'endedAt': endedAt!.toUtc().toIso8601String(),
    }, fallback: 'Não foi possível salvar as mudanças. Tente de novo.');
  }

  /// Um participante sai da sessão (🟡 a confirmar com o grupo). O dono não sai.
  /// O dono da sessão troca o nome de um lance (a Function `renameHighlight`). Valida antes
  /// de chamar, com as mesmas regras do servidor. Devolve o nome como ficou gravado.
  Future<String> renameHighlight({
    required String sessionId,
    required String highlightId,
    required String title,
  }) async {
    _check('sessionId', validateHighlightRef(sessionId));
    _check('highlightId', validateHighlightRef(highlightId));
    _check('title', validateHighlightRename(title));
    final normalized = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    final data = await _call(
      'renameHighlight',
      {'sessionId': sessionId, 'highlightId': highlightId, 'title': normalized},
      fallback: 'Não foi possível renomear o lance. Tente de novo.',
    );
    return data['title'] as String? ?? normalized;
  }

  /// O dono exclui a sessão para todos, com os lances e os vídeos (Function deleteSession).
  /// Excluir de novo, ou uma sessão que nunca chegou ao servidor, não é erro.
  Future<void> deleteSession(String sessionId) async {
    _check('sessionId', validateEntityId(sessionId));
    await _call('deleteSession', {'sessionId': sessionId},
        fallback: 'Não foi possível excluir a sessão. Tente de novo.');
  }

  /// O dono apaga um lance para todos, com o vídeo e a miniatura (Function deleteHighlight).
  Future<void> deleteHighlight({required String sessionId, required String highlightId}) async {
    _check('sessionId', validateHighlightRef(sessionId));
    _check('highlightId', validateHighlightRef(highlightId));
    await _call('deleteHighlight', {'sessionId': sessionId, 'highlightId': highlightId},
        fallback: 'Não foi possível apagar o lance. Tente de novo.');
  }

  Future<void> leaveSession(String sessionId) async {
    _check('sessionId', validateEntityId(sessionId));
    await _call('leaveSession', {'sessionId': sessionId},
        fallback: 'Não foi possível sair da sessão. Tente de novo.');
  }

  /// As sessões que dá para juntar a [into] (D18): de outro dono, em que eu participo,
  /// ainda não juntadas e gravadas no mesmo jogo (até [mergeToleranceMinutes] de diferença).
  ///
  /// Filtra a lista que a Início já tem, sem ir ao banco.
  static List<Session> mergeCandidates(Session into, List<Session> mySessions) {
    const tolerance = Duration(minutes: mergeToleranceMinutes);
    final intoEnd = into.endedAt ?? into.startedAt.add(into.duration);
    return mySessions.where((s) {
      if (s.id == into.id || s.ownerId == into.ownerId || s.isMerged) return false;
      if (into.mergedFrom.contains(s.id)) return false;
      final end = s.endedAt ?? s.startedAt.add(s.duration);
      return !s.startedAt.isAfter(intoEnd.add(tolerance)) &&
          !into.startedAt.isAfter(end.add(tolerance));
    }).toList(growable: false);
  }

  /// Pede ao dono de [fromSessionId] para juntar a sessão dele à minha [intoSessionId] (D18).
  /// Devolve o id do pedido.
  Future<String> requestSessionMerge({
    required String intoSessionId,
    required String fromSessionId,
  }) async {
    _check('sessionId', validateEntityId(intoSessionId));
    _check('sessionId', validateEntityId(fromSessionId));
    final data = await _call(
      'requestSessionMerge',
      {'intoSessionId': intoSessionId, 'fromSessionId': fromSessionId},
      fallback: 'Não foi possível pedir para juntar as sessões. Tente de novo.',
    );
    return data['requestId'] as String? ?? '$intoSessionId$mergeRequestSeparator$fromSessionId';
  }

  /// O dono da outra sessão aceita o pedido: os lances dela vão para a principal (D18).
  Future<void> acceptSessionMerge(String requestId) async {
    _check('sessionId', validateMergeRequestId(requestId));
    await _call('acceptSessionMerge', {'requestId': requestId},
        fallback: 'Não foi possível juntar as sessões. Tente de novo.');
  }

  /// Recusa (quem recebeu) ou desiste (quem pediu) de juntar as sessões.
  Future<void> cancelSessionMerge(String requestId) async {
    _check('sessionId', validateMergeRequestId(requestId));
    await _call('cancelSessionMerge', {'requestId': requestId},
        fallback: 'Não foi possível cancelar o pedido. Tente de novo.');
  }

  /// Pedidos para juntar sessões em que estou (os que fiz e os que recebi).
  Stream<List<SessionMergeRequest>> watchMergeRequests() {
    final uid = _auth().currentUser?.uid;
    if (uid == null) {
      return Stream<List<SessionMergeRequest>>.error(
        const SessionsFailure('Entre na sua conta para ver suas sessões.'),
      );
    }
    return _firestore()
        .collection(mergeRequestsCollection)
        .where('uids', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SessionMergeRequest.fromMap(doc.id, doc.data()))
            .toList(growable: false))
        .handleError((Object error) {
      throw SessionsFailure.from(error);
    });
  }

  /// Coleção dos pedidos para juntar sessões. Igual ao de backend/firestore.rules.
  static const String mergeRequestsCollection = 'sessionMergeRequests';

  /// Chama uma Function e traduz o erro para a tela.
  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload, {
    required String fallback,
  }) async {
    try {
      return await _callFunction(name, payload);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final field = details is Map ? details['field'] as String? : null;
      throw SessionsFailure(e.message ?? fallback, code: field ?? e.code);
    } on FirebaseException catch (e) {
      throw SessionsFailure.from(e);
    }
  }

  /// Barra o envio quando a validação do app encontrou um erro.
  static void _check(String field, String? error) {
    if (error != null) throw SessionsFailure(error, code: field);
  }
}

/// Pedido para juntar duas sessões do mesmo jogo (D18).
class SessionMergeRequest {
  const SessionMergeRequest({
    required this.id,
    required this.intoSessionId,
    required this.fromSessionId,
    required this.requestedBy,
    required this.requestedTo,
    required this.intoName,
    required this.fromName,
  });

  factory SessionMergeRequest.fromMap(String id, Map<String, dynamic> data) => SessionMergeRequest(
        id: id,
        intoSessionId: data['intoSessionId'] as String? ?? '',
        fromSessionId: data['fromSessionId'] as String? ?? '',
        requestedBy: data['requestedBy'] as String? ?? '',
        requestedTo: data['requestedTo'] as String? ?? '',
        intoName: data['intoName'] as String? ?? '',
        fromName: data['fromName'] as String? ?? '',
      );

  final String id;

  /// A sessão principal (de quem pediu), que vira o hub.
  final String intoSessionId;

  /// A sessão de quem recebeu o pedido, cujos lances vão para a principal.
  final String fromSessionId;
  final String requestedBy;
  final String requestedTo;
  final String intoName;
  final String fromName;

  /// true quando sou eu quem precisa aceitar ou recusar.
  bool waitsFor(String uid) => requestedTo == uid;
}

/// Um lance salvo pelo gesto, esperando para ser enviado.
///
/// O [highlightId] nasce no aparelho junto com o MP4: é ele que faz o reenvio ser
/// idempotente. O vídeo em [localPath] sobe para o Storage depois que a sessão é salva.
class PendingHighlight {
  const PendingHighlight({
    required this.highlightId,
    required this.localPath,
    required this.offset,
    required this.duration,
    this.title,
  });

  final String highlightId;

  /// Caminho do MP4 na pasta interna do app (o que o buffer devolveu).
  final String localPath;

  /// Momento do lance dentro da sessão.
  final Duration offset;

  /// Quanto o trecho tem de fato: até ~30 s (R1), menos se a sessão era curta (R5).
  final Duration duration;

  /// Vazio vira "Lance N" — ninguém precisa digitar na quadra.
  final String? title;

  Map<String, dynamic> toJson({int? position}) => {
        'highlightId': highlightId,
        'title': position != null ? normalizeHighlightTitle(title, position) : title,
        'offsetSeconds': offset.inSeconds,
        'durationSeconds': duration.inSeconds,
      };
}

SessionsRepository? _sessionsRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
/// Provisório até a área de front-end escolher o gerenciamento de estado.
SessionsRepository get sessionsRepository => _sessionsRepository ??= SessionsRepository();
