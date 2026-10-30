import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/firebase/firebase_setup.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Erro ao ler sessões, com a mensagem pronta para a tela.
///
/// A regra do projeto é nunca mostrar erro técnico: "Erro 503" e
/// "permission-denied" viram frases curtas que dizem o que fazer
/// (docs/design.md › 2. Voz e texto). O [code] fica só para quem for investigar.
class SessionsFailure implements Exception {
  const SessionsFailure(this.message, {this.code});

  /// O que a pessoa lê.
  final String message;

  /// Código do Firebase. Nunca aparece na interface.
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

/// Tudo o que o app lê sobre sessões passa por aqui.
///
/// As telas não falam direto com o Firestore (regra 4 do AGENTS.md): chamam estes
/// métodos. Hoje este repositório só lê — a escrita (criar sessão, salvar highlight)
/// ainda está bloqueada nas Security Rules até o grupo decidir quem grava
/// (docs/arquitetura.md › Quem grava sessões e highlights).
class SessionsRepository {
  SessionsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: functionsRegion);

  /// Nome da coleção no Firestore. Igual ao de backend/firestore.rules.
  static const String collectionName = 'sessions';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  /// As sessões de que a pessoa logada participa, da mais recente para a mais
  /// antiga — é o que a Início lista (produto.md › 4.2).
  ///
  /// Emite de novo a cada mudança no servidor, então a sessão que outro
  /// participante acabou de salvar aparece sozinha, sem recarregar a tela.
  Stream<SessionsSnapshot> watchMySessions() {
    final uid = _auth.currentUser?.uid;
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
    return _firestore
        .collection(collectionName)
        .where('participantIds', arrayContains: uid)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => SessionsSnapshot(
            sessions: snapshot.docs.map(Session.fromDocument).toList(growable: false),
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
  }) async {
    // Nada vai para o servidor sem passar pela validação (regra 0 do AGENTS.md).
    _check('name', validateSessionName(name));
    _check('location', validateLocation(location));
    _check('endedAt', validateSessionPeriod(startedAt, endedAt));

    try {
      final result = await _functions.httpsCallable('saveSession').call<Map<String, dynamic>>({
        'sessionId': sessionId,
        'name': normalizeSessionName(name),
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'location': normalizeLocation(location),
        'participantIds': participantIds,
        'highlights': [for (final h in highlights) h.toJson()],
      });
      final paths = (result.data['videoPaths'] as Map?) ?? const {};
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

  /// Barra o envio quando a validação do app encontrou um erro.
  static void _check(String field, String? error) {
    if (error != null) throw SessionsFailure(error, code: field);
  }
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

  /// Vazio vira "Lance N" no servidor — ninguém precisa digitar na quadra.
  final String? title;

  Map<String, dynamic> toJson() => {
        'highlightId': highlightId,
        'title': title,
        'offsetSeconds': offset.inSeconds,
        'durationSeconds': duration.inSeconds,
      };
}

SessionsRepository? _sessionsRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
/// Provisório até a área de front-end escolher o gerenciamento de estado.
SessionsRepository get sessionsRepository => _sessionsRepository ??= SessionsRepository();
