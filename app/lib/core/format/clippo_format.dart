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

/// "11 set 2026".
///
/// 🟡 Para sessões recentes, o design prevê trocar por "Hoje" e "Ontem"
/// (docs/design.md › Regras de escrita). Ainda não decidido, por isso não é feito aqui.
String clippoDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

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

/// "7 highlights", "1 highlight", "nenhum highlight".
String clippoHighlightCount(int count) {
  if (count == 0) return 'nenhum highlight';
  return count == 1 ? '1 highlight' : '$count highlights';
}

/// "10 participantes", "1 participante".
String clippoParticipantCount(int count) =>
    count == 1 ? '1 participante' : '$count participantes';

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
