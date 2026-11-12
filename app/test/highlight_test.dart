import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/highlight.dart';

void main() {
  test('lê um highlight completo vindo do Firestore', () {
    final savedAt = DateTime(2026, 9, 11, 19, 42, 40);
    final highlight = Highlight.fromMap('hl-1', {
      'title': 'Jogada de cinema',
      'offsetSeconds': 760,
      'durationSeconds': 30,
      'savedAt': Timestamp.fromDate(savedAt),
      'createdBy': 'alice',
      'videoPath': 'sessions/s1/highlights/hl-1/video.mp4',
      'thumbnailPath': 'sessions/s1/highlights/hl-1/thumb.jpg',
      'status': 'uploaded',
    });

    expect(highlight.id, 'hl-1');
    expect(highlight.title, 'Jogada de cinema');
    expect(highlight.offset, const Duration(minutes: 12, seconds: 40));
    expect(highlight.duration, const Duration(seconds: 30));
    expect(highlight.savedAt, savedAt);
    expect(highlight.createdBy, 'alice');
    expect(highlight.status, HighlightStatus.uploaded);
    expect(highlight.isUploading, isFalse);
  });

  test('tolera campos faltando, dá "Lance N" pela posição e marca pending como enviando', () {
    final highlight = Highlight.fromMap('hl-2', const {
      'status': 'pending',
    }, index: 2);

    expect(highlight.title, 'Lance 3');
    expect(highlight.offset, Duration.zero);
    expect(highlight.duration, const Duration(seconds: 30));
    expect(highlight.isUploading, isTrue);
  });

  test('mostra o título como o servidor gravou: "Lance N" e nomes dados pelo dono', () {
    expect(Highlight.fromMap('a', const {'title': 'Lance 1'}).title, 'Lance 1');
    expect(Highlight.fromMap('b', const {'title': 'Lance 1'}, index: 4).title, 'Lance 1');
    expect(Highlight.fromMap('c', const {'title': '  Voleio do Rafa '}).title, 'Voleio do Rafa');
  });
}
