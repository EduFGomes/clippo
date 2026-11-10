import 'package:cloud_firestore/cloud_firestore.dart';

/// Nomes criativos e genéricos (válidos para qualquer esporte) para que cada
/// highlight da sessão tenha identidade própria sem repetir na mesma sessão.
const List<String> creativeHighlightTitles = [
  'Jogada de cinema',
  'Ponto antológico',
  'Defesa no reflexo',
  'Lance na linha',
  'Virada de jogo',
  'Reflexo absurdo',
  'Sequência perfeita',
  'Deixadinha de mestre',
  'Salva improvável',
  'Ponto decisivo',
  'Leitura de jogo',
  'Cravada sem chance',
  'Disputa ponto a ponto',
  'Recuperação no limite',
  'Fechando com chave de ouro',
  'Momento de pura técnica',
];

final RegExp _genericLancePattern = RegExp(r'^lance(?:\s+\d+)?$', caseSensitive: false);

/// Devolve um título criativo que ainda não foi usado em [usedTitles].
String nextCreativeHighlightTitle(int index, Set<String> usedTitles) {
  for (var offset = 0; offset < creativeHighlightTitles.length; offset++) {
    final candidate = creativeHighlightTitles[(index + offset) % creativeHighlightTitles.length];
    if (usedTitles.add(candidate.toLowerCase())) {
      return candidate;
    }
  }
  // Se a sessão tiver mais lances que o catálogo base, combina com o minuto/ordem sem repetir.
  var suffix = index + 1;
  while (true) {
    final base = creativeHighlightTitles[index % creativeHighlightTitles.length];
    final candidate = '$base #$suffix';
    if (usedTitles.add(candidate.toLowerCase())) {
      return candidate;
    }
    suffix++;
  }
}

/// Garante que todos os highlights de uma sessão tenham nomes criativos e únicos
/// (nunca repete o mesmo título dentro da mesma sessão).
List<Highlight> ensureDistinctHighlightTitles(List<Highlight> highlights) {
  final used = <String>{};
  final result = <Highlight>[];

  for (var i = 0; i < highlights.length; i++) {
    final current = highlights[i];
    final trimmed = current.title.trim();
    final isGeneric = trimmed.isEmpty || _genericLancePattern.hasMatch(trimmed);

    if (!isGeneric && used.add(trimmed.toLowerCase())) {
      result.add(current);
    } else {
      final creative = nextCreativeHighlightTitle(i, used);
      result.add(current.copyWith(title: creative));
    }
  }
  return List<Highlight>.unmodifiable(result);
}

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
  });

  factory Highlight.fromMap(String id, Map<String, dynamic> data, {int index = 0}) {
    final offsetSeconds = (data['offsetSeconds'] as num?)?.toInt() ?? 0;
    final durationSeconds = (data['durationSeconds'] as num?)?.toInt() ?? 30;
    final rawTitle = (data['title'] as String? ?? '').trim();
    final defaultTitle = creativeHighlightTitles[index % creativeHighlightTitles.length];

    return Highlight(
      id: id,
      title: rawTitle.isEmpty || _genericLancePattern.hasMatch(rawTitle) ? defaultTitle : rawTitle,
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

  /// Título curto e criativo do lance ("Jogada de cinema", "Ponto antológico").
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

  /// Caminho da miniatura no Storage (ou URL/caminho local).
  final String? thumbnailPath;

  /// Estado do upload do vídeo (R13).
  final HighlightStatus status;

  /// O MP4 ainda guardado no celular (a fila de envio só apaga depois do `uploaded`, R13).
  /// Só existe no aparelho de quem gravou; nunca vem do Firestore. Com ele, o Player toca e
  /// baixa o lance sem internet.
  final String? localPath;

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
    );
  }

  static final DateTime _unknownDate = DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _dateFrom(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
