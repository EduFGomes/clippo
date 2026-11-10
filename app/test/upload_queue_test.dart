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
  SessionsFailure? saveError;
  final List<String> savedSessions = [];
  final List<String> uploads = [];
  final Map<String, StreamController<Map<String, HighlightStatus>>> statuses = {};

  @override
  String? get currentUid => uid;

  @override
  Future<Map<String, String>> saveSession(QueuedSession session) async {
    savedSessions.add(session.sessionId);
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

  UploadQueue queue({List<Duration> retryDelays = const [], Set<String>? existing}) => UploadQueue(
        backend: backend,
        store: store,
        deleteLocalFile: (path) async => deleted.add(path),
        localFileExists: (path) async => existing?.contains(path) ?? true,
        retryDelays: retryDelays,
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

  test('falha no envio do vídeo mantém o lance e tenta de novo sozinha', () async {
    final q = queue(retryDelays: const [Duration(milliseconds: 1)]);
    backend.failUpload = true;

    expect(await q.submit(_session()), SubmitOutcome.queued);
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
    expect(store.saved.single.highlights.single.videoSent, isTrue);
    await _settle();
    expect(deleted, isEmpty);
    expect(q.state.value.isPending('sessao-123456'), isTrue);
    q.dispose();
  });

  test('lance marcado failed depois do envio é enviado de novo', () async {
    final q = queue(retryDelays: const [Duration(milliseconds: 1)]);
    await q.submit(_session());
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
    expect(q.state.value.isEmpty, isTrue);
    q.dispose();
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
}
