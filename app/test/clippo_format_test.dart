import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/format/clippo_format.dart';

// As regras estão em docs/design.md › 2. Voz e texto › Regras de escrita.
void main() {
  test('data no formato "11 set 2026"', () {
    expect(clippoDate(DateTime(2026, 9, 11)), '11 set 2026');
    expect(clippoDate(DateTime(2026, 1, 3)), '3 jan 2026');
    expect(clippoDate(DateTime(2026, 12, 31)), '31 dez 2026');
  });

  test('horário com dois dígitos e intervalo com travessão', () {
    expect(clippoTime(DateTime(2026, 9, 11, 9, 5)), '09:05');
    expect(
      clippoTimeRange(DateTime(2026, 9, 11, 19, 30), DateTime(2026, 9, 11, 21, 12)),
      '19:30 – 21:12',
    );
    expect(clippoTimeRange(DateTime(2026, 9, 11, 19, 30), null), '19:30');
  });

  test('duração como "1h 42min", "58min" e "2h"', () {
    expect(clippoDuration(const Duration(hours: 1, minutes: 42)), '1h 42min');
    expect(clippoDuration(const Duration(minutes: 58)), '58min');
    expect(clippoDuration(const Duration(hours: 2)), '2h');
    expect(clippoDuration(Duration.zero), '0min');
  });

  test('contagens no singular e no plural', () {
    expect(clippoHighlightCount(7), '7 highlights');
    expect(clippoHighlightCount(1), '1 highlight');
    expect(clippoHighlightCount(0), 'nenhum highlight');
    expect(clippoParticipantCount(10), '10 participantes');
    expect(clippoParticipantCount(1), '1 participante');
  });

  test('saudação muda com a hora e usa o primeiro nome', () {
    expect(clippoGreeting(DateTime(2026, 9, 11, 8)), 'Bom dia');
    expect(clippoGreeting(DateTime(2026, 9, 11, 12)), 'Boa tarde');
    expect(clippoGreeting(DateTime(2026, 9, 11, 21)), 'Boa noite');
    expect(
      clippoGreetingFor('Gustavo Alves', now: DateTime(2026, 9, 11, 21)),
      'Boa noite, Gustavo',
    );
    // Perfil ainda carregando: a saudação aparece sozinha, sem vírgula solta.
    expect(clippoGreetingFor(null, now: DateTime(2026, 9, 11, 21)), 'Boa noite');
    expect(clippoGreetingFor('  ', now: DateTime(2026, 9, 11, 8)), 'Bom dia');
  });

  test('ponto médio junta as informações e ignora o que está vazio', () {
    expect(clippoDotList(['11 set 2026', '7 highlights']), '11 set 2026 · 7 highlights');
    expect(clippoDotList(['1h 42min', '']), '1h 42min');
  });
}
