import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/upload/upload_queue.dart';

/// Firebase de mentira: [failSave]/[failUpload] simulam a quadra sem internet.
class FakeUploadBackend implements UploadBackend {
  FakeUploadBackend({this.uid = 'dono'});

  String? uid;
  bool failSave = false;
  bool failUpload = false;
  bool failThumbnail = false;
  SessionsFailure? saveError;

  /// Internet lenta: o `saveSession` só responde quando o teste completar.
  Completer<void>? saveGate;
  final List<String> savedSessions = [];
  final List<String> uploads = [];
  final List<String> thumbnails = [];
  final Map<String, StreamController<Map<String, HighlightStatus>>> statuses = {};

  @override
  String? get currentUid => uid;

  @override
  Future<Map<String, String>> saveSession(QueuedSession session) async {
    savedSessions.add(session.sessionId);
    await saveGate?.future;
    if (saveError != null) throw saveError!;
    if (failSave) {
      throw const SessionsFailure('Sem internet. Suas sessões aparecem assim que você conectar.');
    }
    return {
      for (final h in session.highlights)
        h.highlightId: 'sessions/${session.sessionId}/highlights/${h.highlightId}/video.mp4',
    };
  }

  @override
  Future<void> uploadVideo({required String storagePath, required File localFile}) async {
    uploads.add(storagePath);
    if (failUpload) throw const SocketException('sem rede');
  }

  @override
  Future<void> uploadThumbnail({required String storagePath, required File localFile}) async {
    thumbnails.add(storagePath);
    if (failThumbnail) throw const SocketException('sem rede');
  }

  @override
  Stream<Map<String, HighlightStatus>> watchStatuses(String sessionId) =>
      (statuses[sessionId] ??= StreamController.broadcast()).stream;

  void emit(String sessionId, Map<String, HighlightStatus> value) => statuses[sessionId]!.add(value);
}

QueuedSession _session({String id = 'sessao-123456', String owner = 'dono', int highlights = 1}) => QueuedSession(
      sessionId: id,
      ownerUid: owner,
      name: 'Pelada de quarta',
      startedAt: DateTime.utc(2026, 11, 4, 20),
      endedAt: DateTime.utc(2026, 11, 4, 21),
      participantIds: const ['rafa'],
      highlights: [
        for (var i = 1; i <= highlights; i++)
          QueuedHighlight(
            highlightId: 'highlight_$i',
            localPath: '/data/highlights/highlight_$i.mp4',
            offset: Duration(minutes: i),
            duration: const Duration(seconds: 30),
          ),
      ],
    );

/// Deixa as microtarefas e os listeners da fila rodarem.
Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late FakeUploadBackend backend;
  late MemoryUploadQueueStore store;
  late List<String> deleted;

  UploadQueue queue({
    List<Duration> retryDelays = const [],
    Set<String>? existing,
    Duration submitWait = UploadQueue.defaultSubmitWait,
    Future<String> Function(String videoPath)? makeThumbnail,
  }) =>
      UploadQueue(
        backend: backend,
        store: store,
        deleteLocalFile: (path) async => deleted.add(path),
        localFileExists: (path) async => existing?.contains(path) ?? true,
        retryDelays: retryDelays,
        submitWait: submitWait,
        makeThumbnail: makeThumbnail,
      );

  setUp(() {
    backend = FakeUploadBackend();
    store = MemoryUploadQueueStore();
    deleted = [];
  });

  test('sem internet: a sessão fica guardada no aparelho e vai de novo depois', () async {
    final q = queue();
    backend.failSave = true;

    expect(await q.submit(_session()), SubmitOutcome.queued);
    expect(store.saved, hasLength(1));
    expect(store.saved.single.saved, isFalse);
    expect(store.saved.single.attempts, 1);
    expect(q.state.value.isPending('sessao-123456'), isTrue);
    expect(q.state.value.unsavedSessions, hasLength(1));
    expect(backend.uploads, isEmpty);

    backend.failSave = false;
    await q.retryNow();
    expect(backend.savedSessions, ['sessao-123456', 'sessao-123456']);
    expect(store.saved.single.saved, isTrue);
    expect(backend.uploads, ['sessions/sessao-123456/highlights/highlight_1/video.mp4']);
    expect(store.saved.single.highlights.single.videoSent, isTrue);
    q.dispose();
  });

  test('excluir a sessão: sai da fila, apaga o MP4 do aparelho e não volta ao servidor', () async {
    final q = queue();
    backend.failSave = true;
    expect(await q.submit(_session()), SubmitOutcome.queued);

    await q.discard('sessao-123456');
    expect(q.state.value.isPending('sessao-123456'), isFalse);
    expect(store.saved, isEmpty);
    expect(deleted, contains('/data/highlights/highlight_1.mp4'));

    // A internet volta: nada a reenviar.
    backend.failSave = false;
    await q.retryNow();
    expect(backend.savedSessions, ['sessao-123456']);
    expect(backend.uploads, isEmpty);

    await q.discard('sessao-123456'); // de novo: não é erro
    q.dispose();
  });

  test('apagar um lance: só ele sai da fila e do aparelho; os outros continuam subindo', () async {
    final q = queue();
    backend.failSave = true;
    await q.submit(_session(highlights: 2));
    await q.discardHighlight('sessao-123456', 'highlight_1');
    expect(store.saved.single.highlights.map((h) => h.highlightId), ['highlight_2']);
    expect(deleted, contains('/data/highlights/highlight_1.mp4'));
    expect(deleted, isNot(contains('/data/highlights/highlight_2.mp4')));
    q.dispose();
  });

  test('excluir a conta: todas as sessões da pessoa saem da fila; as de outra conta ficam', () async {
    final q = queue();
    backend.failSave = true;
    await q.submit(_session(id: 'sessao-aaaaaa'));
    await q.submit(_session(id: 'sessao-bbbbbb', owner: 'outra'));
    await q.discardAllOf('dono');
    expect(store.saved.map((s) => s.sessionId), ['sessao-bbbbbb']);
    q.dispose();
  });

  test('falha no envio do vídeo mantém o lance e tenta de novo sozinha', () async {
    final q = queue(retryDelays: const [Duration(milliseconds: 1)]);
    backend.failUpload = true;

    // A sessão foi criada: o "Salvar" termina, e o vídeo falha depois, por trás.
    expect(await q.submit(_session()), SubmitOutcome.saved);
    await _settle();
    expect(store.saved.single.saved, isTrue);
    expect(store.saved.single.highlights.single.videoSent, isFalse);
    expect(q.nextRetryAt, isNotNull);

    backend.failUpload = false;
    await _settle();
    expect(backend.uploads.length, greaterThanOrEqualTo(2));
    expect(store.saved.single.highlights.single.videoSent, isTrue);
    q.dispose();
  });

  test('o vídeo local só é apagado depois que o Firestore marca uploaded', () async {
    final q = queue();
    await q.submit(_session(highlights: 2));
    await _settle();
    expect(backend.uploads, hasLength(2));
    expect(deleted, isEmpty);

    backend.emit('sessao-123456', {
      'highlight_1': HighlightStatus.pending,
      'highlight_2': HighlightStatus.pending,
    });
    await _settle();
    expect(deleted, isEmpty);

    backend.emit('sessao-123456', {
      'highlight_1': HighlightStatus.uploaded,
      'highlight_2': HighlightStatus.pending,
    });
    await _settle();
    expect(deleted, ['/data/highlights/highlight_1.mp4']);
    expect(q.state.value.pendingHighlightIds('sessao-123456'), {'highlight_2'});

    backend.emit('sessao-123456', {
      'highlight_1': HighlightStatus.uploaded,
      'highlight_2': HighlightStatus.uploaded,
    });
    await _settle();
    expect(deleted, ['/data/highlights/highlight_1.mp4', '/data/highlights/highlight_2.mp4']);
    expect(q.state.value.isEmpty, isTrue);
    expect(store.saved, isEmpty);
    q.dispose();
  });

  test('upload terminou mas o Firestore ainda não confirmou: nada é apagado', () async {
    final q = queue();
    await q.submit(_session());
    await _settle();
    expect(store.saved.single.highlights.single.videoSent, isTrue);
    expect(deleted, isEmpty);
    expect(q.state.value.isPending('sessao-123456'), isTrue);
    q.dispose();
  });

  test('lance marcado failed depois do envio é enviado de novo', () async {
    final q = queue(retryDelays: const [Duration(milliseconds: 1)]);
    await q.submit(_session());
    await _settle();
    expect(backend.uploads, hasLength(1));

    backend.emit('sessao-123456', {'highlight_1': HighlightStatus.failed});
    await _settle();
    expect(backend.uploads, hasLength(2));
    expect(deleted, isEmpty);
    q.dispose();
  });

  test('erro de campo do servidor sobe para a tela e não fica na fila', () async {
    final q = queue();
    backend.saveError = const SessionsFailure('Só dá para gravar com os seus amigos.', code: 'participantIds');

    await expectLater(
      q.submit(_session()),
      throwsA(isA<SessionsFailure>().having((e) => e.code, 'code', 'participantIds')),
    );
    expect(store.saved, isEmpty);
    expect(q.state.value.isEmpty, isTrue);
    q.dispose();
  });

  test('internet lenta: o Salvar não espera; a sessão e o vídeo sobem por trás', () async {
    final q = queue(submitWait: const Duration(milliseconds: 10));
    backend.saveGate = Completer<void>();

    expect(await q.submit(_session()), SubmitOutcome.queued);
    expect(store.saved.single.saved, isFalse);
    expect(backend.uploads, isEmpty);

    backend.saveGate!.complete();
    await _settle();
    expect(store.saved.single.saved, isTrue);
    expect(backend.uploads, ['sessions/sessao-123456/highlights/highlight_1/video.mp4']);
    q.dispose();
  });

  test('recusa do servidor depois da espera: a sessão fica guardada e para de tentar', () async {
    final q = queue(submitWait: const Duration(milliseconds: 10));
    backend.saveGate = Completer<void>();
    backend.saveError = const SessionsFailure('Só dá para gravar com os seus amigos.', code: 'participantIds');

    expect(await q.submit(_session()), SubmitOutcome.queued);
    backend.saveGate!.complete();
    await _settle();
    expect(store.saved.single.blocked, isTrue);
    expect(store.saved.single.lastError, 'Só dá para gravar com os seus amigos.');
    expect(deleted, isEmpty);
    q.dispose();
  });

  test('ao abrir o app, retoma a fila guardada (sessão não salva + vídeos não enviados)', () async {
    store = MemoryUploadQueueStore([_session()]);
    final q = queue();
    await q.start(listenToLifecycle: false);
    expect(backend.savedSessions, ['sessao-123456']);
    expect(backend.uploads, hasLength(1));

    // Outra instância (o app aberto de novo) não reenvia o vídeo já enviado.
    q.dispose();
    final again = queue();
    await again.start(listenToLifecycle: false);
    expect(backend.uploads, hasLength(1));
    again.dispose();
  });

  test('só envia as sessões de quem está logado', () async {
    store = MemoryUploadQueueStore([_session(owner: 'outra-pessoa')]);
    final q = queue();
    await q.start(listenToLifecycle: false);
    expect(backend.savedSessions, isEmpty);
    expect(q.state.value.isPending('sessao-123456'), isTrue);
    q.dispose();
  });

  test('sessão sem lances sai da fila assim que é salva', () async {
    final q = queue();
    expect(await q.submit(_session(highlights: 0)), SubmitOutcome.saved);
    await _settle();
    expect(q.state.value.isEmpty, isTrue);
    q.dispose();
  });

  test('withLocalVideos: põe o MP4 do celular nos lances do servidor e acrescenta os só locais', () {
    final state = UploadQueueState(sessions: [_session(highlights: 2)]);
    final remote = [
      Highlight(
        id: 'highlight_2',
        title: 'Ponto antológico',
        offset: const Duration(minutes: 2),
        duration: const Duration(seconds: 30),
        savedAt: DateTime.utc(2026, 11, 4, 20, 2),
        createdBy: 'dono',
        status: HighlightStatus.pending,
      ),
      Highlight(
        id: 'outro',
        title: 'De outro celular',
        offset: const Duration(minutes: 5),
        duration: const Duration(seconds: 30),
        savedAt: DateTime.utc(2026, 11, 4, 20, 5),
        createdBy: 'rafa',
      ),
    ];

    final merged = state.withLocalVideos('sessao-123456', remote);
    expect(merged.map((h) => h.id), ['highlight_1', 'highlight_2', 'outro']);
    expect(merged[0].localPath, '/data/highlights/highlight_1.mp4');
    expect(merged[0].status, HighlightStatus.pending);
    expect(merged[1].localPath, '/data/highlights/highlight_2.mp4');
    expect(merged[1].title, 'Ponto antológico');
    expect(merged[2].hasLocalVideo, isFalse);

    expect(state.withLocalVideos('outra-sessao', remote), same(remote));
  });

  test('a fila guardada em arquivo sobrevive a fechar o app', () async {
    final dir = await Directory.systemTemp.createTemp('clippo-fila');
    addTearDown(() => dir.delete(recursive: true));
    final fileStore = FileUploadQueueStore(directory: () async => dir);

    await fileStore.save([_session(highlights: 2)]);
    final loaded = await fileStore.load();
    expect(loaded.single.sessionId, 'sessao-123456');
    expect(loaded.single.highlights.map((h) => h.highlightId), ['highlight_1', 'highlight_2']);
    expect(loaded.single.participantIds, ['rafa']);
    expect(loaded.single.startedAt, DateTime.utc(2026, 11, 4, 20));
  });

  test('lance que só está no celular aparece como "Lance N", o nome que o servidor vai gravar', () {
    final state = UploadQueueState(sessions: [_session(highlights: 3)]);
    final shown = state.withLocalVideos('sessao-123456', const []);
    expect([for (final h in shown) h.title], ['Lance 1', 'Lance 2', 'Lance 3']);
  });

  group('miniatura do lance', () {
    Future<String> jpegBeside(String video) async => video.replaceAll('.mp4', '.jpg');

    test('gera um quadro de cada MP4 e envia no thumb.jpg, ao lado do vídeo, uma vez só', () async {
      final made = <String>[];
      final q = queue(makeThumbnail: (video) {
        made.add(video);
        return jpegBeside(video);
      });
      await q.submit(_session());
      await _settle();

      expect(made, ['/data/highlights/highlight_1.mp4']);
      expect(backend.thumbnails, ['sessions/sessao-123456/highlights/highlight_1/thumb.jpg']);
      expect(q.state.value.thumbnails, {'highlight_1': '/data/highlights/highlight_1.jpg'});
      // A tela Sessão recebe a miniatura do aparelho junto com o vídeo local.
      final shown = q.state.value.withLocalVideos('sessao-123456', const []);
      expect(shown.single.localThumbnailPath, '/data/highlights/highlight_1.jpg');

      await q.retryNow();
      await _settle();
      expect(made, hasLength(1));
      expect(backend.thumbnails, hasLength(1));
      q.dispose();
    });

    test('sem internet: a miniatura já existe no aparelho, e só sobe depois de a sessão ser salva', () async {
      final q = queue(makeThumbnail: jpegBeside);
      backend.failSave = true;
      await q.submit(_session());
      await _settle();
      expect(q.state.value.thumbnails, {'highlight_1': '/data/highlights/highlight_1.jpg'});
      expect(backend.thumbnails, isEmpty);

      backend.failSave = false;
      await q.retryNow();
      await _settle();
      expect(backend.thumbnails, ['sessions/sessao-123456/highlights/highlight_1/thumb.jpg']);
      q.dispose();
    });

    test('falha ao gerar a miniatura: o vídeo sobe e o lance sai da fila do mesmo jeito', () async {
      final q = queue(makeThumbnail: (_) async => throw StateError('sem quadro'));
      expect(await q.submit(_session()), SubmitOutcome.saved);
      await _settle();
      expect(backend.uploads, ['sessions/sessao-123456/highlights/highlight_1/video.mp4']);
      expect(backend.thumbnails, isEmpty);
      expect(q.state.value.thumbnails, isEmpty);
      expect(q.nextRetryAt, isNull);

      backend.emit('sessao-123456', {'highlight_1': HighlightStatus.uploaded});
      await _settle();
      expect(deleted, ['/data/highlights/highlight_1.mp4']);
      expect(q.state.value.isEmpty, isTrue);
      q.dispose();
    });

    test('falha ao enviar a miniatura não marca nova tentativa nem segura o lance', () async {
      final q = queue(makeThumbnail: jpegBeside, retryDelays: const [Duration(minutes: 1)]);
      backend.failThumbnail = true;
      await q.submit(_session());
      await _settle();
      expect(store.saved.single.highlights.single.videoSent, isTrue);
      expect(store.saved.single.attempts, 0);
      expect(q.nextRetryAt, isNull);

      backend.emit('sessao-123456', {'highlight_1': HighlightStatus.uploaded});
      await _settle();
      expect(q.state.value.isEmpty, isTrue);
      expect(q.state.value.thumbnails, isEmpty);
      q.dispose();
    });

    test('miniatura que nunca termina não atrasa o envio do vídeo', () async {
      final stuck = Completer<String>();
      final q = queue(makeThumbnail: (_) => stuck.future);
      expect(await q.submit(_session(highlights: 2)), SubmitOutcome.saved);
      await _settle();
      expect(backend.uploads, hasLength(2));

      backend.emit('sessao-123456', {
        'highlight_1': HighlightStatus.uploaded,
        'highlight_2': HighlightStatus.uploaded,
      });
      await _settle();
      expect(q.state.value.isEmpty, isTrue);
      q.dispose();
    });

    test('sem gerador de miniatura (testes, catálogo), a fila só envia os vídeos', () async {
      final q = queue();
      await q.submit(_session());
      await _settle();
      expect(backend.uploads, hasLength(1));
      expect(backend.thumbnails, isEmpty);
      q.dispose();
    });
  });
}
