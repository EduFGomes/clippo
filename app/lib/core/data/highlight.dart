import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado do envio do vídeo no Storage (R13).
enum HighlightStatus {
  /// O gesto salvou o lance no aparelho, mas o vídeo ainda está subindo.
  pending,

  /// Vídeo confirmado no Storage.
  uploaded,

  /// Envio falhou e será tentado de novo.
  failed;

  static HighlightStatus fromString(String? raw) {
    switch (raw) {
      case 'uploaded':
        return HighlightStatus.uploaded;
      case 'failed':
        return HighlightStatus.failed;
      case 'pending':
      default:
        return HighlightStatus.pending;
    }
  }
}

/// Um highlight: trecho de ~30 s salvo pelo gesto \ o / dentro de uma sessão.
/// Espelha o documento `sessions/{sessionId}/highlights/{highlightId}` descrito
/// em docs/arquitetura.md › Modelo de dados.
class Highlight {
  const Highlight({
    required this.id,
    required this.title,
    required this.offset,
    required this.duration,
    required this.savedAt,
    required this.createdBy,
    this.videoPath,
    this.thumbnailPath,
    this.status = HighlightStatus.uploaded,
    this.localPath,
    this.localThumbnailPath,
  });

  factory Highlight.fromMap(String id, Map<String, dynamic> data, {int index = 0}) {
    final offsetSeconds = (data['offsetSeconds'] as num?)?.toInt() ?? 0;
    final durationSeconds = (data['durationSeconds'] as num?)?.toInt() ?? 30;
    final rawTitle = (data['title'] as String? ?? '').trim();

    return Highlight(
      id: id,
      // O saveSession grava "Lance N"; só um documento sem título cai aqui (o nome pela posição).
      title: rawTitle.isEmpty ? 'Lance ${index + 1}' : rawTitle,
      offset: Duration(seconds: offsetSeconds < 0 ? 0 : offsetSeconds),
      duration: Duration(seconds: durationSeconds <= 0 ? 30 : durationSeconds),
      savedAt: _dateFrom(data['savedAt']) ?? _unknownDate,
      createdBy: data['createdBy'] as String? ?? '',
      videoPath: data['videoPath'] as String?,
      thumbnailPath: data['thumbnailPath'] as String?,
      status: HighlightStatus.fromString(data['status'] as String?),
    );
  }

  factory Highlight.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    int index = 0,
  }) =>
      Highlight.fromMap(doc.id, doc.data() ?? const {}, index: index);

  /// ID do documento na subcoleção `highlights`.
  final String id;

  /// Título curto do lance: nasce "Lance 3" (pela ordem na sessão) e o dono da sessão pode
  /// renomear ("Voleio do Rafa").
  final String title;

  /// Momento em que foi salvo desde o início da sessão ("00:12:40").
  final Duration offset;

  /// Duração do trecho (~30 s, ou menos se a sessão era curta — R5).
  final Duration duration;

  /// Data/hora em que o gesto aconteceu.
  final DateTime savedAt;

  /// UID de quem estava gravando a sessão.
  final String createdBy;

  /// Caminho do MP4 no Storage (ou nulo enquanto não definido).
  final String? videoPath;

  /// Caminho da miniatura no Storage (`.../thumb.jpg`). O arquivo pode ainda não existir.
  final String? thumbnailPath;

  /// Estado do upload do vídeo (R13).
  final HighlightStatus status;

  /// O MP4 ainda guardado no celular (a fila de envio só apaga depois do `uploaded`, R13).
  /// Só existe no aparelho de quem gravou; nunca vem do Firestore. Com ele, o Player toca e
  /// baixa o lance sem internet.
  final String? localPath;

  /// A miniatura (JPEG) ainda guardada no celular de quem gravou, ao lado do MP4. Como o
  /// [localPath], nunca vem do Firestore: quem preenche é a fila de envio.
  final String? localThumbnailPath;

  /// true quando o vídeo pode tocar direto do celular, sem baixar da nuvem.
  bool get hasLocalVideo => (localPath ?? '').isNotEmpty;

  /// true enquanto o vídeo ainda está subindo para o banco ("enviando…").
  bool get isUploading => status == HighlightStatus.pending;

  Highlight copyWith({
    String? title,
    Duration? offset,
    Duration? duration,
    DateTime? savedAt,
    String? createdBy,
    String? videoPath,
    String? thumbnailPath,
    HighlightStatus? status,
    String? localPath,
    String? localThumbnailPath,
  }) {
    return Highlight(
      id: id,
      title: title ?? this.title,
      offset: offset ?? this.offset,
      duration: duration ?? this.duration,
      savedAt: savedAt ?? this.savedAt,
      createdBy: createdBy ?? this.createdBy,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      localThumbnailPath: localThumbnailPath ?? this.localThumbnailPath,
    );
  }

  static final DateTime _unknownDate = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
