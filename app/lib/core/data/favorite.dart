import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:clippo/core/data/highlight.dart';

/// Um lance favoritado (R18–R21): o documento `posts/{uid}__{sessionId}__{highlightId}` de
/// docs/arquitetura.md › Modelo de dados. Aparece no perfil de quem favoritou, para os amigos.
///
/// Só traz o que pode aparecer para quem não jogou a sessão (R20): o vídeo, o título, a data e
/// quem favoritou. Nada do nome da sessão, do local ou dos participantes.
class FavoritePost {
  const FavoritePost({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerUsername,
    required this.sessionId,
    required this.highlightId,
    required this.title,
    required this.duration,
    required this.playedAt,
    required this.videoPath,
    this.ownerPhotoUrl,
    this.thumbnailPath,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory FavoritePost.fromMap(String id, Map<String, dynamic> data) {
    final owner = data['owner'] is Map ? Map<String, dynamic>.from(data['owner'] as Map) : const <String, dynamic>{};
    final seconds = (data['durationSeconds'] as num?)?.toInt() ?? 30;
    return FavoritePost(
      id: id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: owner['name'] as String? ?? '',
      ownerUsername: owner['username'] as String? ?? '',
      ownerPhotoUrl: owner['photoUrl'] as String?,
      sessionId: data['sessionId'] as String? ?? '',
      highlightId: data['highlightId'] as String? ?? '',
      title: (data['title'] as String? ?? '').trim(),
      duration: Duration(seconds: seconds <= 0 ? 30 : seconds),
      playedAt: _dateFrom(data['playedAt']) ?? _dateFrom(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      videoPath: data['videoPath'] as String? ?? '',
      thumbnailPath: data['thumbnailPath'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  factory FavoritePost.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FavoritePost.fromMap(doc.id, doc.data() ?? const {});

  final String id;

  /// Quem favoritou.
  final String ownerId;
  final String ownerName;
  final String ownerUsername;
  final String? ownerPhotoUrl;

  /// De onde o lance veio. Só o app de quem favoritou usa (para desfavoritar); a tela não mostra.
  final String sessionId;
  final String highlightId;

  final String title;
  final Duration duration;

  /// Quando o lance aconteceu (o `savedAt` dele).
  final DateTime playedAt;

  /// A cópia própria do vídeo (D19): `posts/{id}/video.mp4`.
  final String videoPath;
  final String? thumbnailPath;

  final int likeCount;
  final int commentCount;

  /// "Leo", para "Favorito de Leo".
  String get ownerFirstName {
    final first = ownerName.trim().split(RegExp(r'\s+')).first;
    return first.isEmpty ? '@$ownerUsername' : first;
  }

  /// O favorito como um lance que o Player sabe tocar: o vídeo é a cópia do favorito.
  Highlight toHighlight() => Highlight(
        id: id,
        title: title.isEmpty ? 'Lance' : title,
        offset: Duration.zero,
        duration: duration,
        savedAt: playedAt,
        createdBy: ownerId,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
      );

  FavoritePost copyWith({int? likeCount, int? commentCount}) => FavoritePost(
        id: id,
        ownerId: ownerId,
        ownerName: ownerName,
        ownerUsername: ownerUsername,
        ownerPhotoUrl: ownerPhotoUrl,
        sessionId: sessionId,
        highlightId: highlightId,
        title: title,
        duration: duration,
        playedAt: playedAt,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
      );
}

/// Um comentário num favorito (R22): `posts/{id}/comments/{commentId}`.
class FavoriteComment {
  const FavoriteComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    this.authorPhotoUrl,
    this.createdAt,
  });

  factory FavoriteComment.fromMap(String id, Map<String, dynamic> data) {
    final author = data['author'] is Map ? Map<String, dynamic>.from(data['author'] as Map) : const <String, dynamic>{};
    return FavoriteComment(
      id: id,
      authorId: data['authorId'] as String? ?? '',
      authorName: author['name'] as String? ?? '',
      authorPhotoUrl: author['photoUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: _dateFrom(data['createdAt']),
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;

  /// Nulo logo depois de comentar, até o servidor carimbar a hora.
  final DateTime? createdAt;
}

DateTime? _dateFrom(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
