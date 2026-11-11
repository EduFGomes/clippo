import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Um lance esperando para subir (R13): o MP4 na pasta interna do app e, depois que o
/// `saveSession` respondeu, o caminho dele no Storage.
@immutable
class QueuedHighlight {
  const QueuedHighlight({
    required this.highlightId,
    required this.localPath,
    required this.offset,
    required this.duration,
    this.title,
    this.videoPath,
    this.videoSent = false,
  });

  factory QueuedHighlight.fromPending(PendingHighlight h) => QueuedHighlight(
        highlightId: h.highlightId,
        localPath: h.localPath,
        offset: h.offset,
        duration: h.duration,
        title: h.title,
      );

  factory QueuedHighlight.fromJson(Map<String, dynamic> json) => QueuedHighlight(
        highlightId: json['highlightId'] as String,
        localPath: json['localPath'] as String,
        offset: Duration(seconds: (json['offsetSeconds'] as num).toInt()),
        duration: Duration(seconds: (json['durationSeconds'] as num).toInt()),
        title: json['title'] as String?,
        videoPath: json['videoPath'] as String?,
        videoSent: json['videoSent'] as bool? ?? false,
      );

  final String highlightId;

  /// O MP4 em `filesDir/highlights/`. Só é apagado depois do `uploaded` no Firestore.
  final String localPath;
  final Duration offset;
  final Duration duration;
  final String? title;

  /// Onde o vídeo sobe no Storage (vem do `saveSession`). Nulo antes de a sessão ser salva.
  final String? videoPath;

  /// O `putFile` terminou. Falta o gatilho `onVideoUploaded` marcar `uploaded`.
  final bool videoSent;

  PendingHighlight toPending() => PendingHighlight(
        highlightId: highlightId,
        localPath: localPath,
        offset: offset,
        duration: duration,
        title: title,
      );

  QueuedHighlight copyWith({String? videoPath, bool? videoSent}) => QueuedHighlight(
        highlightId: highlightId,
        localPath: localPath,
        offset: offset,
        duration: duration,
        title: title,
        videoPath: videoPath ?? this.videoPath,
        videoSent: videoSent ?? this.videoSent,
      );

  Map<String, dynamic> toJson() => {
        'highlightId': highlightId,
        'localPath': localPath,
        'offsetSeconds': offset.inSeconds,
        'durationSeconds': duration.inSeconds,
        'title': title,
        'videoPath': videoPath,
        'videoSent': videoSent,
      };
}

/// Uma sessão na fila: os dados do "Salvar sessão" e os lances que ainda não subiram.
///
/// Sai da fila quando foi salva no servidor e todos os lances estão `uploaded`.
@immutable
class QueuedSession {
  const QueuedSession({
    required this.sessionId,
    required this.ownerUid,
    required this.name,
    required this.startedAt,
    required this.endedAt,
    this.location,
    this.participantIds = const [],
    this.highlights = const [],
    this.saved = false,
    this.attempts = 0,
    this.lastError,
    this.blocked = false,
  });

  factory QueuedSession.fromJson(Map<String, dynamic> json) => QueuedSession(
        sessionId: json['sessionId'] as String,
        ownerUid: json['ownerUid'] as String,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        endedAt: DateTime.parse(json['endedAt'] as String),
        location: json['location'] as String?,
        participantIds: [...(json['participantIds'] as List<dynamic>? ?? const []).cast<String>()],
        highlights: [
          for (final h in json['highlights'] as List<dynamic>? ?? const [])
            QueuedHighlight.fromJson((h as Map).cast<String, dynamic>()),
        ],
        saved: json['saved'] as bool? ?? false,
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        lastError: json['lastError'] as String?,
        blocked: json['blocked'] as bool? ?? false,
      );

  final String sessionId;

  /// Quem gravou. A fila só envia as sessões de quem está logado agora.
  final String ownerUid;
  final String name;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? location;
  final List<String> participantIds;

  /// Os lances que ainda não estão `uploaded`.
  final List<QueuedHighlight> highlights;

  /// O `saveSession` já respondeu: a sessão existe no Firestore.
  final bool saved;

  /// Quantas tentativas falharam seguidas.
  final int attempts;

  /// A última frase de erro (pronta para a tela), ou nulo.
  final String? lastError;

  /// O servidor recusou os dados (ex.: "Só dá para gravar com os seus amigos." numa nova
  /// tentativa). A fila para de tentar sozinha e guarda tudo até alguém resolver.
  final bool blocked;

  /// A sessão como a Início a desenha enquanto ela só existe no aparelho (R13): quem gravou
  /// aparece como "Você"; os amigos escolhidos entram só na contagem, porque a fila guarda
  /// os uids, não os nomes.
  Session toSession() {
    final length = endedAt.difference(startedAt);
    final place = location;
    return Session(
      id: sessionId,
      name: name,
      ownerId: ownerUid,
      participantIds: [ownerUid, for (final uid in participantIds) if (uid != ownerUid) uid],
      participants: [SessionParticipant(uid: ownerUid, name: 'Você')],
      participantCount: 1 + participantIds.where((uid) => uid != ownerUid).length,
      startedAt: startedAt,
      endedAt: endedAt,
      duration: length.isNegative ? Duration.zero : length,
      location: place == null || place.isEmpty ? null : SessionLocation(label: place),
      highlightCount: highlights.length,
    );
  }

  QueuedSession copyWith({
    List<QueuedHighlight>? highlights,
    bool? saved,
    int? attempts,
    String? lastError,
    bool clearError = false,
    bool? blocked,
  }) =>
      QueuedSession(
        sessionId: sessionId,
        ownerUid: ownerUid,
        name: name,
        startedAt: startedAt,
        endedAt: endedAt,
        location: location,
        participantIds: participantIds,
        highlights: highlights ?? this.highlights,
        saved: saved ?? this.saved,
        attempts: attempts ?? this.attempts,
        lastError: clearError ? null : (lastError ?? this.lastError),
        blocked: blocked ?? this.blocked,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'ownerUid': ownerUid,
        'name': name,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'location': location,
        'participantIds': participantIds,
        'highlights': [for (final h in highlights) h.toJson()],
        'saved': saved,
        'attempts': attempts,
        'lastError': lastError,
        'blocked': blocked,
      };
}

/// O que a fila tem agora. É isto que a Início lê para mostrar "enviando…".
@immutable
class UploadQueueState {
  const UploadQueueState({this.sessions = const [], this.thumbnails = const {}});

  /// A miniatura (JPEG no aparelho) de cada lance da fila que já tem uma, pelo id do lance.
  final Map<String, String> thumbnails;

  /// Sessões com algo pendente: ainda não salvas no servidor e/ou com lances subindo.
  final List<QueuedSession> sessions;

  bool get isEmpty => sessions.isEmpty;

  QueuedSession? sessionOf(String sessionId) {
    for (final s in sessions) {
      if (s.sessionId == sessionId) return s;
    }
    return null;
  }

  /// true enquanto a sessão tem algo para enviar.
  bool isPending(String sessionId) => sessionOf(sessionId) != null;

  /// Os lances da sessão que ainda não estão `uploaded`.
  Set<String> pendingHighlightIds(String sessionId) =>
      {for (final h in sessionOf(sessionId)?.highlights ?? const <QueuedHighlight>[]) h.highlightId};

  /// Sessões que ainda não chegaram ao servidor (a Início pode listá-las a partir daqui).
  List<QueuedSession> get unsavedSessions => [for (final s in sessions) if (!s.saved) s];

  /// O que a Início escreve no card de uma sessão que ainda tem algo na fila, ou nulo.
  String? noteFor(String sessionId) {
    final queued = sessionOf(sessionId);
    if (queued == null) return null;
    if (queued.blocked) return 'envio parado';
    if (queued.attempts > 0) return 'sobe quando conectar';
    return 'enviando…';
  }

  /// Os lances da sessão com o MP4 do celular de quem gravou, para assistir antes de subir.
  ///
  /// Os lances do Firestore ([remote]) que ainda estão na fila ganham o `localPath`. Os que
  /// só existem na fila (a sessão ainda não chegou ao servidor) entram como `pending`.
  /// Sem nada na fila, devolve [remote] como veio.
  List<Highlight> withLocalVideos(String sessionId, List<Highlight> remote) {
    final queued = sessionOf(sessionId);
    if (queued == null || queued.highlights.isEmpty) return remote;
    final local = {for (final h in queued.highlights) h.highlightId: h};
    final merged = <Highlight>[
      for (final h in remote)
        if (local[h.id] case final q?)
          h.copyWith(localPath: q.localPath, localThumbnailPath: thumbnails[h.id])
        else
          h,
    ];
    final known = {for (final h in remote) h.id};
    for (var i = 0; i < queued.highlights.length; i++) {
      final q = queued.highlights[i];
      if (known.contains(q.highlightId)) continue;
      merged.add(Highlight(
        id: q.highlightId,
        // O mesmo nome que o saveSession vai gravar: "Lance N" pela ordem do lance na sessão.
        title: normalizeHighlightTitle(q.title, i + 1),
        offset: q.offset,
        duration: q.duration,
        savedAt: queued.startedAt.add(q.offset),
        createdBy: queued.ownerUid,
        status: HighlightStatus.pending,
        localPath: q.localPath,
        localThumbnailPath: thumbnails[q.highlightId],
      ));
    }
    merged.sort((a, b) => a.offset.compareTo(b.offset));
    return merged;
  }
}

/// Resultado do [UploadQueue.submit].
enum SubmitOutcome {
  /// O `saveSession` respondeu; os vídeos estão subindo.
  saved,

  /// Sem internet ou falha passageira: a sessão ficou guardada no aparelho e vai de novo depois.
  queued,
}

/// O que a fila precisa do Firebase. Separado para os testes rodarem sem Firebase.
abstract class UploadBackend {
  /// Quem está logado agora (nulo: ninguém).
  String? get currentUid;

  /// Chama o `saveSession` e devolve o caminho do vídeo de cada lance.
  Future<Map<String, String>> saveSession(QueuedSession session);

  Future<void> uploadVideo({required String storagePath, required File localFile});

  /// Envia a miniatura JPEG do lance (`thumb.jpg`, ao lado do vídeo).
  Future<void> uploadThumbnail({required String storagePath, required File localFile});

  /// O estado de cada lance da sessão no Firestore, em tempo real.
  Stream<Map<String, HighlightStatus>> watchStatuses(String sessionId);
}

/// [UploadBackend] de verdade: os repositórios de `core/data/`.
class FirebaseUploadBackend implements UploadBackend {
  FirebaseUploadBackend({SessionsRepository? sessions, HighlightMediaRepository? media})
      : _sessionsOverride = sessions,
        _mediaOverride = media;

  final SessionsRepository? _sessionsOverride;
  final HighlightMediaRepository? _mediaOverride;

  SessionsRepository get _s => _sessionsOverride ?? sessionsRepository;
  HighlightMediaRepository get _m => _mediaOverride ?? highlightMediaRepository;

  @override
  String? get currentUid {
    try {
      return authRepository.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Map<String, String>> saveSession(QueuedSession session) => _s.saveSession(
        sessionId: session.sessionId,
        name: session.name,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        location: session.location,
        participantIds: session.participantIds,
        highlights: [for (final h in session.highlights) h.toPending()],
      );

  @override
  Future<void> uploadVideo({required String storagePath, required File localFile}) =>
      _m.uploadVideo(storagePath: storagePath, localFile: localFile);

  @override
  Future<void> uploadThumbnail({required String storagePath, required File localFile}) =>
      _m.uploadThumbnail(storagePath: storagePath, localFile: localFile);

  @override
  Stream<Map<String, HighlightStatus>> watchStatuses(String sessionId) =>
      _s.watchHighlightsOf(sessionId).map((snapshot) => {
            for (final h in snapshot.highlights) h.id: h.status,
          });
}

/// Onde a fila fica guardada no aparelho.
abstract class UploadQueueStore {
  Future<List<QueuedSession>> load();
  Future<void> save(List<QueuedSession> sessions);
}

/// Um JSON na pasta de suporte do app (não é cache: o Android não apaga sozinho).
class FileUploadQueueStore implements UploadQueueStore {
  FileUploadQueueStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  static const String fileName = 'upload_queue.json';

  final Future<Directory> Function() _directory;

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<List<QueuedSession>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString());
      return [
        for (final item in raw as List<dynamic>)
          QueuedSession.fromJson((item as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      // Arquivo corrompido: guarda uma cópia para não perder nada e começa de novo.
      await file.copy('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      return [];
    }
  }

  @override
  Future<void> save(List<QueuedSession> sessions) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Escreve ao lado e troca: se o app morrer no meio, o arquivo antigo continua inteiro.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode([for (final s in sessions) s.toJson()]), flush: true);
    await temp.rename(file.path);
  }
}

/// Fila em memória, para os testes e o catálogo de telas.
class MemoryUploadQueueStore implements UploadQueueStore {
  MemoryUploadQueueStore([List<QueuedSession> initial = const []]) : saved = [...initial];

  List<QueuedSession> saved;

  @override
  Future<List<QueuedSession>> load() async => [...saved];

  @override
  Future<void> save(List<QueuedSession> sessions) async => saved = [...sessions];
}

/// A fila de envio da Gravação (R13, D15).
///
/// 1. "Salvar sessão" → [submit] guarda a sessão no aparelho **antes** de tentar a rede.
/// 2. Chama o `saveSession`. Sem internet: fica guardada e vai de novo depois.
/// 3. Envia cada MP4 para o `videoPath` devolvido.
/// 4. Ouve o Firestore; quando o lance fica `uploaded`, apaga o MP4 local e tira da fila.
///
/// Ao lado disso, sem nunca entrar na frente do vídeo, a fila gera a miniatura de cada lance
/// (um quadro do MP4) e a envia: veja [UploadQueue.makeThumbnail].
///
/// Tenta de novo sozinha com espera crescente ([retryDelays]), quando o app volta para a
/// frente e quando o app abre ([start]). 🟡 Com o app fechado ainda não (WorkManager):
/// [drain] já é a peça que uma tarefa em segundo plano chamaria.
class UploadQueue {
  UploadQueue({
    required UploadBackend backend,
    required UploadQueueStore store,
    Future<void> Function(String path)? deleteLocalFile,
    Future<bool> Function(String path)? localFileExists,
    this.makeThumbnail,
    this.retryDelays = defaultRetryDelays,
    this.submitWait = defaultSubmitWait,
  })  : _api = backend,
        _storage = store,
        _deleteLocalFile = deleteLocalFile ?? _deleteFile,
        _localFileExists = localFileExists ?? ((path) => File(path).exists());

  static const List<Duration> defaultRetryDelays = [
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  final UploadBackend _api;
  final UploadQueueStore _storage;
  final Future<void> Function(String path) _deleteLocalFile;
  final Future<bool> Function(String path) _localFileExists;
  final List<Duration> retryDelays;

  /// Gera a miniatura do MP4 em `videoPath` e devolve o caminho do JPEG (no app,
  /// `ClippoCamera.extractThumbnail`). Nulo: a fila não gera nem envia miniaturas.
  ///
  /// A miniatura é um extra: roda numa fila à parte, fora do caminho do gesto (R2) e do envio
  /// do vídeo. Se gerar ou enviar falhar, o lance sobe do mesmo jeito e a tela mostra o
  /// desenho de quadra.
  final Future<String> Function(String videoPath)? makeThumbnail;

  /// Quanto cada miniatura pode demorar (gerar + enviar) antes de a fila passar para a próxima.
  static const Duration thumbnailWait = Duration(seconds: 30);

  /// Quanto o "Salvar sessão" espera o servidor criar a sessão antes de seguir sem ele.
  static const Duration defaultSubmitWait = Duration(seconds: 5);
  final Duration submitWait;

  final ValueNotifier<UploadQueueState> _state = ValueNotifier(const UploadQueueState());

  /// O que está na fila agora. A Início pode ouvir com um `ValueListenableBuilder`.
  ValueListenable<UploadQueueState> get state => _state;

  List<QueuedSession> _sessions = [];
  final Map<String, StreamSubscription<Map<String, HighlightStatus>>> _watching = {};
  Future<void> _tail = Future<void>.value();

  /// As miniaturas ficam só na memória: depois de fechar o app, a próxima passada as
  /// reencontra no aparelho (o nativo devolve o JPEG que já existe).
  final Map<String, String> _thumbnails = {};
  final Set<String> _thumbnailsSent = {};
  Future<void> _thumbnailTail = Future<void>.value();
  Future<void>? _loaded;
  Timer? _retryTimer;
  int _failures = 0;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  /// Quando a próxima tentativa automática está marcada (nulo: nenhuma).
  DateTime? nextRetryAt;

  /// Quem está logado agora: é o dono das sessões que entram na fila.
  String? get currentUid => _api.currentUid;

  static Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  /// Carrega o que ficou guardado e começa a enviar. Chame quando o app abrir, já logado.
  Future<void> start({bool listenToLifecycle = true}) async {
    await _load();
    if (listenToLifecycle && _lifecycle == null) {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(retryNow()));
    }
    await drain();
  }

  Future<void> _load() => _loaded ??= _serial(() async {
        final stored = await _storage.load();
        final known = {for (final s in _sessions) s.sessionId};
        _sessions = [..._sessions, ...stored.where((s) => !known.contains(s.sessionId))];
        _publish();
      });

  /// Guarda a sessão no aparelho e tenta criá-la no servidor, esperando no máximo
  /// [submitWait]. Os vídeos sobem sempre por trás: a tela nunca espera por eles.
  ///
  /// Se o servidor recusar um campo (ex.: `participantIds`) dentro da espera, a sessão sai da
  /// fila e o [SessionsFailure] sobe para a tela mostrar no campo certo. Sem internet, internet
  /// lenta ou recusa depois da espera: a sessão fica na fila e devolve [SubmitOutcome.queued]
  /// (uma recusa tardia deixa a sessão `blocked`, com a mensagem em `lastError`).
  Future<SubmitOutcome> submit(QueuedSession session) async {
    await _load();
    final id = session.sessionId;
    final saving = _serial(() async {
      _sessions = [
        for (final s in _sessions)
          if (s.sessionId != id) s,
        session,
      ];
      await _persist();
      // Já gera as miniaturas: sem internet, a Sessão mostra os lances com a imagem certa.
      _startThumbnails();
      return _saveOnServer(id);
    });

    final ({_Step step, SessionsFailure? refused}) result;
    try {
      result = await saving.timeout(submitWait);
    } on TimeoutException {
      // Internet lenta: a chamada segue por trás; quando terminar, a fila continua sozinha.
      unawaited(saving.then((late) {
        if (late.step == _Step.retryLater) {
          _scheduleRetry();
        } else {
          unawaited(drain().catchError((Object _) {}));
        }
      }, onError: (Object _) => _scheduleRetry()));
      return SubmitOutcome.queued;
    }

    final refused = result.refused;
    if (refused != null) {
      await _serial(() async {
        _sessions = [for (final s in _sessions) if (s.sessionId != id) s];
        await _persist();
      });
      throw refused;
    }
    if (result.step == _Step.retryLater) {
      // Sem internet: a fila tenta de novo com espera crescente.
      _scheduleRetry();
      return SubmitOutcome.queued;
    }
    // Sessão criada: os vídeos sobem por trás.
    unawaited(drain().catchError((Object _) {}));
    return SubmitOutcome.saved;
  }

  /// Tenta agora tudo o que está na fila (zera a espera).
  Future<void> retryNow() {
    _failures = 0;
    return drain();
  }

  /// Uma passada pela fila inteira.
  Future<void> drain() async {
    await _load();
    _retryTimer?.cancel();
    _retryTimer = null;
    nextRetryAt = null;
    _startThumbnails();
    final needsRetry = await _serial(() async {
      var retry = false;
      for (final id in [for (final s in _sessions) s.sessionId]) {
        if (await _process(id) == _Step.retryLater) retry = true;
      }
      return retry;
    });
    if (needsRetry) {
      _scheduleRetry();
    } else {
      _failures = 0;
    }
  }

  void _scheduleRetry() {
    if (_disposed || retryDelays.isEmpty) return;
    final delay = retryDelays[_failures.clamp(0, retryDelays.length - 1)];
    _failures++;
    _retryTimer?.cancel();
    nextRetryAt = DateTime.now().add(delay);
    _retryTimer = Timer(delay, () => unawaited(drain()));
  }

  /// Cria a sessão no servidor (o `saveSession`), se ainda não foi. Uma recusa de campo deixa a
  /// sessão `blocked` e volta em `refused`, para o [submit] mostrar no campo certo.
  Future<({_Step step, SessionsFailure? refused})> _saveOnServer(String sessionId) async {
    final session = _find(sessionId);
    if (session == null || session.saved) return (step: _Step.done, refused: null);
    final uid = _api.currentUid;
    if (uid == null || uid != session.ownerUid) return (step: _Step.done, refused: null);
    try {
      final paths = await _api.saveSession(session);
      // Relido: os lances podem ter mudado enquanto a chamada estava fora.
      final now = _find(sessionId) ?? session;
      await _replace(now.copyWith(
        saved: true,
        attempts: 0,
        clearError: true,
        blocked: false,
        highlights: [
          for (final h in now.highlights)
            h.copyWith(
              videoPath: paths[h.highlightId] ??
                  'sessions/${now.sessionId}/highlights/${h.highlightId}/video.mp4',
            ),
        ],
      ));
      return (step: _Step.done, refused: null);
    } on SessionsFailure catch (e) {
      if (e.code != null) {
        // O servidor recusou um campo: tentar de novo sozinho não vai resolver.
        await _replace(session.copyWith(lastError: e.message, blocked: true));
        return (step: _Step.done, refused: e);
      }
      await _replace(session.copyWith(attempts: session.attempts + 1, lastError: e.message));
      return (step: _Step.retryLater, refused: null);
    } catch (_) {
      await _replace(session.copyWith(
        attempts: session.attempts + 1,
        lastError: 'Sem internet. A sessão sobe quando a conexão voltar.',
      ));
      return (step: _Step.retryLater, refused: null);
    }
  }

  Future<_Step> _process(String sessionId) async {
    final found = _find(sessionId);
    if (found == null) return _Step.done;
    final uid = _api.currentUid;
    if (uid == null || uid != found.ownerUid) return _Step.done;
    if (found.blocked) return _Step.done;

    if (!found.saved) {
      final saved = await _saveOnServer(sessionId);
      if (saved.step == _Step.retryLater) return _Step.retryLater;
    }
    final session = _find(sessionId);
    if (session == null || !session.saved) return _Step.done;

    _watch(session.sessionId);
    // A sessão existe no servidor: as miniaturas já podem subir, ao lado dos vídeos.
    _startThumbnails();

    for (final h in session.highlights) {
      final current = _find(sessionId)?.highlights.where((x) => x.highlightId == h.highlightId);
      if (current == null || current.isEmpty) continue; // já confirmado pelo Firestore
      final highlight = current.first;
      if (highlight.videoSent) continue;
      final file = File(highlight.localPath);
      if (!await _localFileExists(highlight.localPath)) {
        // Sem o arquivo não há o que enviar; o Firestore ainda pode confirmar um envio antigo.
        continue;
      }
      try {
        await _api.uploadVideo(storagePath: highlight.videoPath!, localFile: file);
        await _updateHighlight(sessionId, highlight.highlightId, (x) => x.copyWith(videoSent: true));
      } catch (e) {
        final s = _find(sessionId);
        if (s != null) {
          await _replace(s.copyWith(
            attempts: s.attempts + 1,
            lastError: e is HighlightMediaFailure ? e.message : 'A conexão caiu. Tente de novo.',
          ));
        }
        return _Step.retryLater;
      }
    }

    final after = _find(sessionId);
    if (after != null && after.highlights.isEmpty) {
      // Sessão sem lances (ou todos já confirmados): nada mais a fazer.
      _sessions = [for (final s in _sessions) if (s.sessionId != sessionId) s];
      _stopWatching(sessionId);
      await _persist();
    } else if (after != null && after.attempts != 0) {
      await _replace(after.copyWith(attempts: 0, clearError: true));
    }
    return _Step.done;
  }

  /// Ouve o Firestore: lance `uploaded` → apaga o MP4 local e tira da fila (R13).
  void _watch(String sessionId) {
    if (_watching.containsKey(sessionId)) return;
    _watching[sessionId] = _api.watchStatuses(sessionId).listen(
      (statuses) => unawaited(_serial(() => _onStatuses(sessionId, statuses))),
      onError: (Object _) => _stopWatching(sessionId),
      onDone: () => _stopWatching(sessionId),
    );
  }

  void _stopWatching(String sessionId) {
    _watching.remove(sessionId)?.cancel();
  }

  Future<void> _onStatuses(String sessionId, Map<String, HighlightStatus> statuses) async {
    final session = _find(sessionId);
    if (session == null) {
      _stopWatching(sessionId);
      return;
    }
    final remaining = <QueuedHighlight>[];
    var resend = false;
    for (final h in session.highlights) {
      final status = statuses[h.highlightId];
      if (status == HighlightStatus.uploaded) {
        try {
          await _deleteLocalFile(h.localPath);
        } catch (_) {
          // Não conseguiu apagar: não faz mal, o lance já está no banco.
        }
        // Fora da fila principal: apagar alguns KB não precisa segurar o resto do envio.
        unawaited(_forgetThumbnail(h));
      } else if (status == HighlightStatus.failed && h.videoSent) {
        // O gatilho recusou o arquivo: manda de novo.
        remaining.add(h.copyWith(videoSent: false));
        resend = true;
      } else {
        remaining.add(h);
      }
    }
    if (remaining.length == session.highlights.length && !resend) return;
    if (remaining.isEmpty && session.saved) {
      _sessions = [for (final s in _sessions) if (s.sessionId != sessionId) s];
      _stopWatching(sessionId);
      await _persist();
    } else {
      await _replace(session.copyWith(highlights: remaining));
    }
    if (resend) _scheduleRetry();
  }

  /// Põe uma passada das miniaturas na fila delas. Nunca espera nem falha para quem chama.
  void _startThumbnails() {
    if (makeThumbnail == null || _disposed) return;
    _thumbnailTail = _thumbnailTail.then((_) => _thumbnailPass()).catchError((Object _) {});
  }

  Future<void> _thumbnailPass() async {
    final uid = _api.currentUid;
    if (uid == null) return;
    final pending = [
      for (final s in _sessions)
        if (s.ownerUid == uid)
          for (final h in s.highlights)
            if (!_thumbnailsSent.contains(h.highlightId)) (s.sessionId, h.highlightId),
    ];
    for (final (sessionId, highlightId) in pending) {
      if (_disposed) return;
      try {
        await _thumbnailOf(sessionId, highlightId).timeout(thumbnailWait);
      } catch (_) {
        // Sem miniatura desta vez: o lance segue sem ela e a próxima passada tenta de novo.
      }
    }
  }

  QueuedHighlight? _findHighlight(String sessionId, String highlightId) {
    for (final h in _find(sessionId)?.highlights ?? const <QueuedHighlight>[]) {
      if (h.highlightId == highlightId) return h;
    }
    return null;
  }

  Future<void> _thumbnailOf(String sessionId, String highlightId) async {
    final queued = _findHighlight(sessionId, highlightId);
    if (queued == null) return;
    var local = _thumbnails[highlightId];
    if (local == null) {
      if (!await _localFileExists(queued.localPath)) return;
      local = await makeThumbnail!(queued.localPath);
      if (_disposed) return;
      if (_findHighlight(sessionId, highlightId) == null) {
        // O lance saiu da fila enquanto a miniatura era gerada: não sobra arquivo solto.
        await _deleteFile(local);
        return;
      }
      _thumbnails[highlightId] = local;
      _publish();
    }

    final session = _find(sessionId);
    final videoPath = _findHighlight(sessionId, highlightId)?.videoPath;
    if (session == null || !session.saved || session.blocked || videoPath == null) return;
    try {
      await _api.uploadThumbnail(storagePath: thumbnailPathFor(videoPath), localFile: File(local));
      _thumbnailsSent.add(highlightId);
    } on HighlightMediaFailure catch (e) {
      // As regras só aceitam a miniatura uma vez: a recusa quer dizer que ela já está lá.
      if (e.code == 'unauthorized') _thumbnailsSent.add(highlightId);
      rethrow;
    }
  }

  /// A miniatura fica ao lado do vídeo no Storage (`.../video.mp4` → `.../thumb.jpg`), como
  /// o `saveSession` grava em `thumbnailPath`.
  static String thumbnailPathFor(String videoPath) {
    final slash = videoPath.lastIndexOf('/');
    return '${videoPath.substring(0, slash + 1)}thumb.jpg';
  }

  /// O lance subiu: a miniatura local sai junto com o MP4.
  Future<void> _forgetThumbnail(QueuedHighlight highlight) async {
    _thumbnailsSent.remove(highlight.highlightId);
    final known = _thumbnails.remove(highlight.highlightId);
    final video = highlight.localPath;
    final paths = <String>{
      ?known,
      // Onde o nativo a grava (mesmo nome do MP4, `.jpg`), caso esta execução ainda não a conheça.
      if (video.toLowerCase().endsWith('.mp4')) '${video.substring(0, video.length - 4)}.jpg',
    };
    for (final path in paths) {
      try {
        await _deleteFile(path);
      } catch (_) {
        // Não conseguiu apagar: são poucos KB, e o lance já está no banco.
      }
    }
  }

  QueuedSession? _find(String sessionId) {
    for (final s in _sessions) {
      if (s.sessionId == sessionId) return s;
    }
    return null;
  }

  Future<void> _replace(QueuedSession session) async {
    _sessions = [for (final s in _sessions) s.sessionId == session.sessionId ? session : s];
    await _persist();
  }

  Future<void> _updateHighlight(
    String sessionId,
    String highlightId,
    QueuedHighlight Function(QueuedHighlight) change,
  ) async {
    final session = _find(sessionId);
    if (session == null) return;
    await _replace(session.copyWith(highlights: [
      for (final h in session.highlights) h.highlightId == highlightId ? change(h) : h,
    ]));
  }

  Future<void> _persist() async {
    _publish();
    await _storage.save(_sessions);
  }

  void _publish() {
    if (_disposed) return;
    _state.value = UploadQueueState(
      sessions: List.unmodifiable(_sessions),
      thumbnails: Map.unmodifiable(_thumbnails),
    );
  }

  /// Uma operação de cada vez: a fila nunca envia o mesmo lance duas vezes ao mesmo tempo.
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _lifecycle?.dispose();
    for (final sub in _watching.values) {
      sub.cancel();
    }
    _watching.clear();
    _state.dispose();
  }
}

enum _Step { done, retryLater }

UploadQueue? _uploadQueue;

/// Instância única usada pelo app. Só acesse depois de setupFirebase() (main.dart).
UploadQueue get uploadQueue => _uploadQueue ??= UploadQueue(
      backend: FirebaseUploadBackend(),
      store: FileUploadQueueStore(),
      makeThumbnail: const ClippoCamera().extractThumbnail,
    );
