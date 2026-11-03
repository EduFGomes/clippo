import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/validation/input_validation.dart';

// Estas regras precisam bater com backend/functions/src/users/validation.ts.
// Mudou um caso aqui? Mude no backend/functions/test/validation.test.ts.
void main() {
  group('e-mail', () {
    test('aceita e normaliza um e-mail comum', () {
      expect(normalizeEmail('  Nome.Sobrenome+1@Aluno.Br '), 'nome.sobrenome+1@aluno.br');
      expect(validateEmail('  Nome.Sobrenome+1@Aluno.Br '), isNull);
    });

    test('recusa vazio, sem domínio completo e pontos fora do lugar', () {
      for (final bad in [
        '',
        '   ',
        'sem-arroba',
        'nome@',
        '@dominio.com',
        'nome@g', // o Auth aceita; a nossa regra não
        'nome@dominio',
        'nome@dominio.c',
        'nome@.dominio.com',
        'nome@dominio..com',
        '.nome@dominio.com',
        'nome.@dominio.com',
        'no..me@dominio.com',
        'nome cognome@dominio.com',
      ]) {
        expect(validateEmail(bad), isNotNull, reason: 'deveria recusar "$bad"');
      }
    });
  });

  group('senha', () {
    test('nova senha: mínimo de 6 caracteres', () {
      expect(validateNewPassword(''), 'Informe a senha.');
      expect(validateNewPassword('12345'), 'Use uma senha com pelo menos 6 caracteres.');
      expect(validateNewPassword('123456'), isNull);
      expect(validateNewPassword('a' * 129), isNotNull);
    });

    test('confirmação precisa bater com a senha', () {
      expect(validatePasswordConfirmation('123456', ''), 'Repita a senha.');
      expect(validatePasswordConfirmation('123456', '123457'), 'As senhas não são iguais.');
      expect(validatePasswordConfirmation('123456', '123456'), isNull);
    });
  });

  group('nome', () {
    test('junta espaços repetidos e recusa vazio ou longo demais', () {
      expect(normalizeName('  Maria   Clara '), 'Maria Clara');
      expect(validateName('  Maria   Clara '), isNull);
      expect(validateName('   '), 'Informe seu nome.');
      expect(validateName('a' * 51), isNotNull);
    });
  });

  group('nome de usuário', () {
    test('tira o @ da frente, põe em minúsculas e aceita pontos e _ no meio', () {
      expect(normalizeUsername(' @Rafa.Costa_9 '), 'rafa.costa_9');
      expect(validateUsername(' @Rafa.Costa_9 '), isNull);
    });

    test('recusa curto, longo, com caracteres fora da regra ou ponto nas pontas', () {
      for (final bad in [
        '',
        'ab',
        'a' * 21,
        'rafa costa',
        'rafa-costa',
        'josé',
        '.rafa',
        'rafa.',
        'ra..fa',
      ]) {
        expect(validateUsername(bad), isNotNull, reason: 'deveria recusar "$bad"');
      }
    });
  });

  group('data de nascimento', () {
    final today = DateTime(2026, 4, 20);
    test('aceita uma data válida no passado', () {
      expect(validateBirthDate(DateTime(2001, 2, 28), today: today), isNull);
      expect(validateBirthDate(today, today: today), isNull);
    });
    test('recusa vazia, futura ou antes de 1900', () {
      expect(validateBirthDate(null, today: today), isNotNull);
      expect(validateBirthDate(DateTime(2027, 1, 1), today: today), isNotNull);
      expect(validateBirthDate(DateTime(1899, 12, 31), today: today), isNotNull);
    });
  });

  group('sessão', () {
    test('nome da sessão: junta espaços e recusa vazio ou longo demais', () {
      expect(normalizeSessionName('  Pelada   de quinta '), 'Pelada de quinta');
      expect(validateSessionName('Pelada de quinta'), isNull);
      expect(validateSessionName('   '), 'Informe o nome da sessão.');
      expect(validateSessionName('a' * 51), 'O nome da sessão pode ter até 50 caracteres.');
    });

    test('local da sessão: aceita vazio, junta espaços e recusa longo demais', () {
      expect(normalizeSessionLocation('  Arena   Society '), 'Arena Society');
      expect(validateSessionLocation(''), isNull);
      expect(validateSessionLocation('Arena Society'), isNull);
      expect(validateSessionLocation('a' * 81), 'O local pode ter até 80 caracteres.');
      expect(normalizeLocation('  Quadra   do Parque '), 'Quadra do Parque');
      expect(validateLocation('a' * (locationMax + 1)), 'O local pode ter até $locationMax caracteres.');
    });
  });
}
