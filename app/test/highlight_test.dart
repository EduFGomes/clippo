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

  test('tolera campos faltando, gera nome criativo e marca pending como enviando', () {
    final highlight = Highlight.fromMap('hl-2', const {
      'status': 'pending',
    });

    expect(highlight.title, 'Jogada de cinema');
    expect(highlight.offset, Duration.zero);
    expect(highlight.duration, const Duration(seconds: 30));
    expect(highlight.isUploading, isTrue);
  });

  test('ensureDistinctHighlightTitles dá nomes criativos e nunca repete na mesma sessão', () {
    final list = ensureDistinctHighlightTitles([
      Highlight(
        id: '1',
        title: 'Lance 1',
        offset: const Duration(minutes: 2),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11),
        createdBy: 'alice',
      ),
      Highlight(
        id: '2',
        title: 'Lance 2',
        offset: const Duration(minutes: 5),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11),
        createdBy: 'alice',
      ),
      Highlight(
        id: '3',
        title: 'Jogada de cinema',
        offset: const Duration(minutes: 9),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11),
        createdBy: 'alice',
      ),
    ]);

    final titles = list.map((h) => h.title).toList();
    expect(titles.toSet().length, list.length);
    expect(titles[0], 'Jogada de cinema');
    expect(titles[1], 'Ponto antológico');
    expect(titles[2], 'Defesa no reflexo');
  });
}
