import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/validation/input_validation.dart';

// Os mesmos casos de backend/functions/test/validation.test.ts e sessions.validation.test.ts:
// as duas regras precisam concordar (regra 0 do AGENTS.md).
void main() {
  group('e-mail', () {
    test('normaliza espaços e maiúsculas', () {
      expect(normalizeEmail('  Voce@Email.com '), 'voce@email.com');
      expect(validateEmail('  Voce@Email.com '), isNull);
    });

    for (final ok in ['rafa+jogo@gmail.com', 'a.b_c@sub.dominio.com.br', 'x@y.io']) {
      test('aceita $ok', () => expect(validateEmail(ok), isNull));
    }

    for (final bad in [
      '',
      '   ',
      'capovill@g',
      'sem-arroba.com',
      'nome@dominio',
      'nome@dominio.c',
      'nome @dominio.com',
      '.nome@dominio.com',
      'nome.@dominio.com',
      'no..me@dominio.com',
      'nome@-dominio.com',
      'nome@dominio..com',
      'nome@dominio.c0m',
      '${'a' * 65}@dominio.com',
      'nome@${'a' * 250}.com',
    ]) {
      test('recusa "$bad"', () => expect(validateEmail(bad), isNotNull));
    }
  });

  group('senha', () {
    test('nova senha: 8 a 128 caracteres, com maiúscula, minúscula e número', () {
      expect(validateNewPassword(''), 'Informe a senha.');
      expect(validateNewPassword('Abc1234'), 'Use uma senha com pelo menos 8 caracteres.');
      expect(validateNewPassword('Abc12345'), isNull);
      expect(validateNewPassword('Ab1${'a' * 125}'), isNull); // 128
      expect(validateNewPassword('Ab1${'a' * 126}'), 'A senha pode ter até 128 caracteres.');
      for (final weak in ['abcd1234', 'ABCD1234', 'Abcdefgh', '12345678']) {
        expect(validateNewPassword(weak), 'Use letra maiúscula, minúscula e número na senha.', reason: weak);
      }
    });

    test('senha de quem entra só precisa estar preenchida (contas antigas têm 6+)', () {
      expect(validateExistingPassword(''), 'Informe a senha.');
      expect(validateExistingPassword('abc123'), isNull);
    });

    test('o medidor sabe o que falta', () {
      final c = passwordChecks('abcdefg1');
      expect(c.length, isTrue);
      expect(c.upper, isFalse);
      expect(c.lower, isTrue);
      expect(c.number, isTrue);
    });

    test('confirmação precisa ser igual', () {
      expect(validatePasswordConfirmation('abc123', ''), isNotNull);
      expect(validatePasswordConfirmation('abc123', 'abc124'), isNotNull);
      expect(validatePasswordConfirmation('abc123', 'abc123'), isNull);
    });

    test('ao entrar, só precisa estar preenchida', () {
      expect(validateExistingPassword(''), isNotNull);
      expect(validateExistingPassword('x'), isNull);
    });
  });

  group('nome', () {
    test('junta espaços repetidos', () => expect(normalizeName('  Rafael   Silva '), 'Rafael Silva'));
    test('recusa vazio ou longo demais', () {
      expect(validateName('   '), isNotNull);
      expect(validateName('a' * 51), isNotNull);
      expect(validateName('Rafael Silva'), isNull);
    });
  });

  group('nome de usuário', () {
    test('tira o @, espaços e deixa minúsculo', () {
      expect(normalizeUsername('  @Rafa_10 '), 'rafa_10');
      expect(validateUsername('  @Rafa_10 '), isNull);
    });
    test('aceita ponto no meio', () => expect(validateUsername('rafa.silva'), isNull));
    for (final bad in ['', 'ra', 'a' * 21, 'rafa silva', 'rafá', '.rafa', 'rafa.', 'ra..fa']) {
      test('recusa "$bad"', () => expect(validateUsername(bad), isNotNull));
    }
  });

  // Os mesmos casos de checkProfilePhoto em backend/functions/test/validation.test.ts.
  group('foto do perfil', () {
    test('aceita JPEG ou PNG de até 2 MB', () {
      expect(validateProfilePhoto(1, 'image/jpeg'), isNull);
      expect(validateProfilePhoto(2 * 1024 * 1024, 'image/png'), isNull);
    });
    test('recusa outro tipo, vazia ou acima de 2 MB', () {
      expect(validateProfilePhoto(100, 'image/gif'), 'Use uma foto em JPEG ou PNG.');
      expect(validateProfilePhoto(100, null), 'Use uma foto em JPEG ou PNG.');
      expect(validateProfilePhoto(0, 'image/jpeg'), 'A foto pode ter até 2 MB.');
      expect(validateProfilePhoto(2 * 1024 * 1024 + 1, 'image/jpeg'), 'A foto pode ter até 2 MB.');
    });
    test('o tipo sai do nome do arquivo', () {
      expect(profilePhotoContentType('/tmp/IMG_01.JPG'), 'image/jpeg');
      expect(profilePhotoContentType('/tmp/a.jpeg'), 'image/jpeg');
      expect(profilePhotoContentType('/tmp/a.png'), 'image/png');
      expect(profilePhotoContentType('/tmp/a.heic'), isNull);
    });
  });

  group('data de nascimento', () {
    final today = DateTime(2026, 10, 13);
    test('aceita uma data válida no passado', () {
      expect(validateBirthDate(DateTime(2001, 2, 28), today: today), isNull);
    });
    // Os mesmos casos de normalizeBirthDate em backend/functions/test/validation.test.ts.
    test('idade mínima de 13 anos: faz 13 hoje entra, um dia antes não', () {
      expect(validateBirthDate(DateTime(2013, 10, 13), today: today), isNull);
      expect(validateBirthDate(DateTime(2013, 10, 14), today: today),
          'Você precisa ter pelo menos 13 anos para usar o Clippo.');
      expect(validateBirthDate(today, today: today), 'Você precisa ter pelo menos 13 anos para usar o Clippo.');
      expect(validateBirthDateText('14/10/2013', today: today),
          'Você precisa ter pelo menos 13 anos para usar o Clippo.');
    });
    test('recusa vazia, futura ou antes de 1900', () {
      expect(validateBirthDate(null, today: today), isNotNull);
      expect(validateBirthDate(DateTime(2027, 1, 1), today: today), isNotNull);
      expect(validateBirthDate(DateTime(1899, 12, 31), today: today), isNotNull);
    });

    test('digitada: "dd/mm/aaaa" vira a data e vai como AAAA-MM-DD', () {
      expect(validateBirthDateText('28/02/2001', today: today), isNull);
      expect(parseBirthDateText(' 28/02/2001 '), DateTime(2001, 2, 28));
      expect(birthDateIso(parseBirthDateText('05/09/1990')!), '1990-09-05');
    });
    test('digitada: vazia pede a data; incompleta, inexistente ou futura é inválida', () {
      expect(validateBirthDateText('  ', today: today), 'Informe a data de nascimento.');
      for (final bad in ['12/03', '12/03/20', '31/02/2001', '00/01/2001', '12/13/2001', '01/01/2027', '31/12/1899']) {
        expect(validateBirthDateText(bad, today: today), 'Data de nascimento inválida.', reason: bad);
      }
    });
  });

  // --- Sessão: espelho de backend/functions/test/sessions.validation.test.ts ---

  group('id vindo do aparelho', () {
    test('aceita o que o app gera', () {
      expect(validateEntityId('sessao_2026-10-29_AbC123'), isNull);
      expect(validateEntityId('lance-0001'), isNull);
    });

    test('recusa id curto, com espaço, com barra ou longo demais', () {
      for (final raw in ['', 'abc', 'com espaco', '../outra', 'a' * 65]) {
        expect(
          validateEntityId(raw),
          'Não foi possível salvar a sessão. Tente de novo.',
        );
      }
    });
  });

  group('nome da sessão', () {
    test('junta espaços e tira os das pontas', () {
      expect(normalizeSessionName('  Pelada   de quinta '), 'Pelada de quinta');
      expect(validateSessionName('  Pelada   de quinta '), isNull);
    });

    test('recusa vazio e só espaços', () {
      for (final raw in ['', '   ']) {
        expect(validateSessionName(raw), 'Dê um nome para a sessão.');
      }
    });

    test('recusa acima do limite', () {
      expect(validateSessionName('a' * sessionNameMax), isNull);
      expect(
        validateSessionName('a' * (sessionNameMax + 1)),
        'O nome da sessão pode ter até $sessionNameMax caracteres.',
      );
    });
  });

  group('local', () {
    test('é opcional: sem local vira null', () {
      for (final raw in [null, '', '   ']) {
        expect(normalizeLocation(raw), isNull);
        expect(validateLocation(raw), isNull);
      }
    });

    test('normaliza e limita', () {
      expect(normalizeLocation('  Quadra   do Parque '), 'Quadra do Parque');
      expect(validateLocation('a' * (locationMax + 1)),
          'O local pode ter até $locationMax caracteres.');
    });
  });

  // Os mesmos casos de checkPeriodFitsHighlights em backend/functions/test/sessions.validation.test.ts.
  group('corrigir data e horário: a sessão vai até o último lance', () {
    test('aceita duração que vai até o último lance, com 1 minuto de folga', () {
      const s = Duration(seconds: 1);
      expect(validatePeriodFitsHighlights(s * 600, [s * 30, s * 300, s * 600]), isNull);
      expect(validatePeriodFitsHighlights(s * 600, [s * 660]), isNull);
      expect(validatePeriodFitsHighlights(s * 600, const []), isNull);
    });

    test('recusa encurtar a sessão para antes do último lance', () {
      const s = Duration(seconds: 1);
      expect(validatePeriodFitsHighlights(s * 600, [s * 30, s * 661]),
          'A sessão precisa durar até o último lance. Confira o horário do fim.');
    });
  });

  group('início e fim da sessão', () {
    final inicio = DateTime.utc(2026, 10, 29, 22, 30);
    final fim = DateTime.utc(2026, 10, 30, 0, 12);
    final agora = DateTime.utc(2026, 10, 30, 1);

    test('aceita um período normal', () {
      expect(validateSessionPeriod(inicio, fim, now: agora), isNull);
    });

    test('recusa data faltando', () {
      expect(validateSessionPeriod(null, fim, now: agora), 'Confira a data e a hora da sessão.');
      expect(validateSessionPeriod(inicio, null, now: agora), 'Confira a data e a hora da sessão.');
    });

    test('recusa fim antes ou igual ao início', () {
      expect(validateSessionPeriod(fim, inicio, now: agora),
          'O fim da sessão precisa vir depois do início.');
      expect(validateSessionPeriod(inicio, inicio, now: agora),
          'O fim da sessão precisa vir depois do início.');
    });

    test('recusa sessão de mais de 12 horas', () {
      expect(
        validateSessionPeriod(DateTime.utc(2026, 10, 29), DateTime.utc(2026, 10, 29, 13),
            now: agora),
        'Uma sessão pode durar até $sessionMaxHours horas.',
      );
    });

    test('recusa fim no futuro, mas tolera 5 min de relógio adiantado', () {
      expect(validateSessionPeriod(inicio, DateTime.utc(2026, 10, 30, 2), now: agora),
          'A sessão não pode terminar no futuro.');
      expect(validateSessionPeriod(inicio, DateTime.utc(2026, 10, 30, 1, 4), now: agora), isNull);
    });
  });

  group('participantes', () {
    test('o dono entra primeiro e sem repetidos (R9)', () {
      expect(
        normalizeParticipantIds(['bob', 'alice', 'bob'], ownerId: 'alice'),
        ['alice', 'bob'],
      );
      expect(normalizeParticipantIds(const [], ownerId: 'alice'), ['alice']);
    });

    test('recusa uid vazio', () {
      expect(
        validateParticipantIds(['bob', ''], ownerId: 'alice'),
        'Confira quem jogou com você.',
      );
    });

    test('recusa acima do limite', () {
      final muitos = List<String>.generate(participantsMax, (i) => 'u$i');
      expect(
        validateParticipantIds(muitos, ownerId: 'alice'),
        'Uma sessão pode ter até $participantsMax participantes.',
      );
      expect(
        validateParticipantIds(muitos.take(participantsMax - 1).toList(), ownerId: 'alice'),
        isNull,
      );
    });
  });

  group('highlights (título, momento e duração)', () {
    test('título vazio vira "Lance N" pela posição', () {
      expect(normalizeHighlightTitle(null, 1), 'Lance 1');
      expect(normalizeHighlightTitle('', 2), 'Lance 2');
      expect(normalizeHighlightTitle('   ', 3), 'Lance 3');
      expect(validateHighlightTitle(null), isNull);
      expect(validateHighlightTitle('   '), isNull);
    });

    test('mantém e normaliza o título que a pessoa escreveu', () {
      expect(normalizeHighlightTitle('  Voleio  do Rafa ', 1), 'Voleio do Rafa');
      expect(validateHighlightTitle('  Voleio  do Rafa '), isNull);
    });

    test('recusa título do lance acima do limite', () {
      expect(validateHighlightTitle('a' * highlightTitleMax), isNull);
      expect(
        validateHighlightTitle('a' * (highlightTitleMax + 1)),
        'O nome do lance pode ter até $highlightTitleMax caracteres.',
      );
    });

    test('renomear: normaliza espaços e aceita até o limite', () {
      expect(validateHighlightRename('  Voleio  do Rafa '), isNull);
      expect(validateHighlightRename('a' * highlightTitleMax), isNull);
    });

    test('renomear: recusa nome vazio ou só espaços', () {
      for (final ruim in [null, '', '   ']) {
        expect(validateHighlightRename(ruim), 'Dê um nome ao lance.');
      }
    });

    test('renomear: recusa nome acima do limite', () {
      expect(
        validateHighlightRename('a' * (highlightTitleMax + 1)),
        'O nome do lance pode ter até $highlightTitleMax caracteres.',
      );
    });

    test('renomear: aceita os ids que o app gera e recusa o resto', () {
      expect(validateHighlightRef('lance-0001'), isNull);
      for (final ruim in ['curto', '../lance-0001', '']) {
        expect(validateHighlightRef(ruim), 'Esse lance não foi encontrado. Tente de novo.');
      }
    });

    test('recusa lance fora da sessão, com 1 min de folga', () {
      expect(
        validateHighlightOffset(-1, sessionDurationSeconds: 6120),
        'Confira o momento dos lances.',
      );
      expect(
        validateHighlightOffset(6200, sessionDurationSeconds: 6120),
        'Confira o momento dos lances.',
      );
      expect(validateHighlightOffset(6150, sessionDurationSeconds: 6120), isNull);
    });

    test('recusa duração zerada, negativa ou absurda', () {
      for (final d in [0, -1, highlightSecondsMax + 1]) {
        expect(validateHighlightDuration(d), 'Confira a duração dos lances.');
      }
      expect(validateHighlightDuration(30), isNull);
      expect(validateHighlightDuration(highlightSecondsMax), isNull);
    });
  });
}
