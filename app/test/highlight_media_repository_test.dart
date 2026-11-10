import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight_media_repository.dart';

void main() {
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
