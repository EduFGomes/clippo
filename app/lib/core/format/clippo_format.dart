/// Como o Clippo escreve data, hora, duração e contagens na interface.
///
/// As regras estão em docs/design.md › 2. Voz e texto › Regras de escrita:
/// números em algarismos, datas como "11 set 2026", horários como "19:30 – 21:12",
/// durações como "1h 42min" e "58min".
///
/// Mudou uma regra lá? Mude aqui e no teste (app/test/clippo_format_test.dart).
library;

const List<String> _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez',
];

/// "11 set 2026". Data exata: campos de formulário e o que precisa do dia certo.
String clippoDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

/// "Hoje", "Ontem" ou "11 set 2026": a data de uma sessão em listas e cabeçalhos
/// (docs/design.md › Regras de escrita; decidido pelo grupo em 12/11/2026).
String clippoRelativeDate(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final todayDay = DateTime(today.year, today.month, today.day);
  if (day == todayDay) return 'Hoje';
  if (day == DateTime(todayDay.year, todayDay.month, todayDay.day - 1)) return 'Ontem';
  return clippoDate(date);
}

/// "19:30".
String clippoTime(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

/// "19:30 – 21:12". Com travessão, como no design, não hífen.
String clippoTimeRange(DateTime start, DateTime? end) =>
    end == null ? clippoTime(start) : '${clippoTime(start)} – ${clippoTime(end)}';

/// "1h 42min", "58min", "2h". Zero vira "0min", nunca vazio.
String clippoDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}min';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}min';
}

/// Tempo de gravação no standby, como relógio: "0:42", "12:05", "1:02:05".
String clippoRecordingTime(Duration elapsed) {
  final total = elapsed.isNegative ? 0 : elapsed.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = (total % 60).toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$seconds';
  return '$hours:${minutes.toString().padLeft(2, '0')}:$seconds';
}

/// "7 highlights", "1 highlight", "nenhum highlight".
String clippoHighlightCount(int count) {
  if (count == 0) return 'nenhum highlight';
  return count == 1 ? '1 highlight' : '$count highlights';
}

/// "7 lances salvos", "1 lance salvo" — cabeçalho da seção Highlights na Sessão.
String clippoSavedPlaysCount(int count) =>
    count == 1 ? '1 lance salvo' : '$count lances salvos';

/// "00:12:40" — momento do highlight desde o início da sessão (docs/design.md › Regras de escrita).
String clippoOffset(Duration offset) {
  final totalSeconds = offset.inSeconds < 0 ? 0 : offset.inSeconds;
  final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((totalSeconds ~/ 60) % 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// "30s" — duração curta de um trecho de highlight.
String clippoShortSeconds(Duration duration) {
  final seconds = duration.inSeconds < 0 ? 0 : duration.inSeconds;
  return '${seconds}s';
}

/// "00:12:40 · 30s", ou "00:12:40 · enviando…" enquanto o vídeo sobe (produto.md › 4.3).
String clippoHighlightTiming(
  Duration offset,
  Duration duration, {
  bool uploading = false,
}) =>
    clippoDotList([
      clippoOffset(offset),
      uploading ? 'enviando…' : clippoShortSeconds(duration),
    ]);

/// "0:12" — tempo corrido no Player.
String clippoPlayerProgress(Duration position) {
  final totalSeconds = position.inSeconds < 0 ? 0 : position.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// O "Baixar" do Player enquanto o vídeo chega: "Baixando 40 %". Sem saber quanto falta
/// (o começo, ou um lance que já está no celular), só "Baixando…".
String clippoDownloadProgress(double? fraction) {
  if (fraction == null) return 'Baixando…';
  final percent = (fraction.clamp(0.0, 1.0) * 100).floor();
  return percent >= 100 ? 'Salvando na galeria…' : 'Baixando $percent %';
}

/// "10 participantes", "1 participante".
String clippoParticipantCount(int count) =>
    count == 1 ? '1 participante' : '$count participantes';

/// "12 sessões juntos", "1 sessão juntos", "nenhuma sessão ainda" (docs/produto.md › 4.6).
String clippoSharedSessionsCount(int count) {
  if (count <= 0) return 'nenhuma sessão ainda';
  return count == 1 ? '1 sessão juntos' : '$count sessões juntos';
}

/// "Bom dia" até 11:59, "Boa tarde" até 17:59, "Boa noite" a partir das 18:00.
String clippoGreeting(DateTime now) {
  if (now.hour < 12) return 'Bom dia';
  return now.hour < 18 ? 'Boa tarde' : 'Boa noite';
}

/// "Boa noite, Gustavo" — saudação com o primeiro nome (docs/design.md › Microcopy).
/// Sem nome (perfil ainda carregando), devolve só a saudação.
String clippoGreetingFor(String? name, {DateTime? now}) {
  final greeting = clippoGreeting(now ?? DateTime.now());
  final first = (name ?? '').trim().split(' ').first;
  return first.isEmpty ? greeting : '$greeting, $first';
}

/// Junta informações da mesma linha com o ponto médio do design: "11 set 2026 · 7 highlights".
String clippoDotList(Iterable<String> parts) =>
    parts.where((part) => part.isNotEmpty).join(' · ');
