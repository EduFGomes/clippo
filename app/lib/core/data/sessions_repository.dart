import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:clippo/core/data/session.dart';

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
  SessionsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Nome da coleção no Firestore. Igual ao de backend/firestore.rules.
  static const String collectionName = 'sessions';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
}

SessionsRepository? _sessionsRepository;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
/// Provisório até a área de front-end escolher o gerenciamento de estado.
SessionsRepository get sessionsRepository => _sessionsRepository ??= SessionsRepository();
