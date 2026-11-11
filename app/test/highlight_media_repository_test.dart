import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight_media_repository.dart';

void main() {
  group('HighlightMediaRepository.videoStream — streaming sem link público (D17)', () {
    HighlightMediaRepository repo({String? idToken = 'id-token', String? appCheck = 'app-check'}) =>
        HighlightMediaRepository(
          storage: _FakeStorage(),
          idToken: () async => idToken,
          appCheckToken: () async => appCheck,
          emulatorOrigin: 'https://firebasestorage.googleapis.com',
        );

    test('aponta para o arquivo no bucket e leva o login e o App Check de quem pede', () async {
      final s = await repo().videoStream('sessions/sessao-0001/highlights/lance-0001/video.mp4');
      expect(
        s.url.toString(),
        'https://firebasestorage.googleapis.com/v0/b/clippo-dev.firebasestorage.app/o/'
        'sessions%2Fsessao-0001%2Fhighlights%2Flance-0001%2Fvideo.mp4?alt=media',
      );
      expect(s.headers, {'Authorization': 'Firebase id-token', 'X-Firebase-AppCheck': 'app-check'});
    });

    test('sem App Check (Emulator), vai só o login', () async {
      final s = await repo(appCheck: null).videoStream('sessions/sessao-0001/highlights/lance-0001/video.mp4');
      expect(s.headers.keys, ['Authorization']);
    });

    test('sem login, recusa antes de montar o pedido', () async {
      await expectLater(
        repo(idToken: null).videoStream('sessions/sessao-0001/highlights/lance-0001/video.mp4'),
        throwsA(isA<HighlightMediaFailure>()),
      );
    });

    test('caminho fora do padrão é recusado', () async {
      await expectLater(repo().videoStream('users/abc/video.mp4'), throwsA(isA<HighlightMediaFailure>()));
    });
  });

  group('HighlightMediaRepository.thumbnailFile — miniatura sem link público (D17)', () {
    const path = 'sessions/sessao-0001/highlights/lance-0001/thumb.jpg';

    test('miniatura já baixada sai do cache, sem falar com o Storage', () async {
      final dir = await Directory.systemTemp.createTemp('clippo-thumbs-test');
      addTearDown(() => dir.delete(recursive: true));
      final cached = File('${dir.path}/clippo-thumbs/${path.replaceAll('/', '_')}');
      await cached.create(recursive: true);
      await cached.writeAsBytes([0xFF, 0xD8, 0xFF]);

      // O _FakeStorage não tem `ref`: se o repositório fosse à rede, o teste quebraria.
      final repo = HighlightMediaRepository(storage: _FakeStorage(), cacheDir: () async => dir);
      expect((await repo.thumbnailFile(path)).path, cached.path);
    });

    test('só aceita o thumb.jpg de um lance', () {
      final repo = HighlightMediaRepository(storage: _FakeStorage());
      for (final ruim in [
        'sessions/sessao-0001/highlights/lance-0001/video.mp4',
        'users/abc/thumb.jpg',
        'https://example.com/thumb.jpg',
      ]) {
        expect(() => repo.thumbnailFile(ruim), throwsA(isA<HighlightMediaFailure>()));
      }
    });
  });

  group('HighlightMediaRepository.checkPath — o mesmo caminho de storage.rules', () {
    test('aceita o vídeo e a miniatura de um lance', () {
      HighlightMediaRepository.checkPath(
        'sessions/sessao-0001/highlights/lance-0001/video.mp4',
        expectedFile: 'video.mp4',
      );
      HighlightMediaRepository.checkPath(
        'sessions/sessao-0001/highlights/lance-0001/thumb.jpg',
        expectedFile: 'thumb.jpg',
      );
    });

    for (final ruim in [
      '',
      'sessions/sessao-0001/highlights/lance-0001/outro.mp4',
      'sessions/../highlights/lance-0001/video.mp4',
      'users/abc/video.mp4',
      'sessions/sessao-0001/highlights/lance-0001/thumb.jpg', // arquivo trocado
    ]) {
      test('recusa "$ruim" antes de chamar o Storage', () {
        expect(
          () => HighlightMediaRepository.checkPath(ruim, expectedFile: 'video.mp4'),
          throwsA(isA<HighlightMediaFailure>()),
        );
      });
    }
  });
}

/// Só o nome do bucket: o resto do Storage não é usado por [HighlightMediaRepository.videoStream].
class _FakeStorage extends Fake implements FirebaseStorage {
  @override
  String get bucket => 'clippo-dev.firebasestorage.app';
}
