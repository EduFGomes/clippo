import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/validation/input_validation.dart';

// Os mesmos casos de backend/functions/test/validation.test.ts: as duas regras precisam concordar.
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
    test('nova senha: 6 a 128 caracteres', () {
      expect(validateNewPassword(''), isNotNull);
      expect(validateNewPassword('abc12'), isNotNull);
      expect(validateNewPassword('abc123'), isNull);
      expect(validateNewPassword('a' * 129), isNotNull);
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

  group('data de nascimento', () {
    final today = DateTime(2026, 10, 13);
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
}
