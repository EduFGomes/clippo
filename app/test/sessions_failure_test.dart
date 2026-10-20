import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/sessions_repository.dart';

SessionsFailure _from(String code) =>
    SessionsFailure.from(FirebaseException(plugin: 'cloud_firestore', code: code));

// Regra do projeto: a pessoa nunca lê código técnico (docs/design.md › 2. Voz e texto).
void main() {
  test('sem internet explica o que vai acontecer', () {
    final failure = _from('unavailable');
    expect(failure.message, 'Sem internet. Suas sessões aparecem assim que você conectar.');
    expect(failure.code, 'unavailable');
  });

  test('cada falha do Firebase tem a sua frase', () {
    expect(_from('deadline-exceeded').message, 'A conexão está lenta. Tente de novo.');
    expect(_from('unauthenticated').message, 'Entre na sua conta para ver suas sessões.');
    expect(
      _from('permission-denied').message,
      'Não foi possível abrir suas sessões. Entre de novo na sua conta.',
    );
    expect(
      _from('resource-exhausted').message,
      'O Clippo está cheio de gente agora. Tente de novo em instantes.',
    );
    // Consulta sem índice é erro nosso: não culpe quem está usando.
    expect(
      _from('failed-precondition').message,
      'Algo deu errado aqui do nosso lado. Avise o time do Clippo.',
    );
  });

  test('erro desconhecido não vaza detalhe técnico para a tela', () {
    final failure = _from('alguma-coisa-nova');
    expect(failure.message, 'Algo deu errado.');
    expect(failure.code, 'alguma-coisa-nova');
  });

  test('nenhuma mensagem contém jargão', () {
    const codes = [
      'unavailable',
      'deadline-exceeded',
      'unauthenticated',
      'permission-denied',
      'resource-exhausted',
      'failed-precondition',
      'qualquer-outro',
    ];
    for (final code in codes) {
      final message = _from(code).message;
      expect(message, isNot(contains(code)));
      expect(message, isNot(contains('Firebase')));
      expect(message, isNot(contains('Exception')));
      expect(message.endsWith('.'), isTrue, reason: 'frase completa termina com ponto');
    }
  });

  test('sem login, pede para entrar', () {
    expect(
      SessionsFailure.from(StateError('ninguém logado')).message,
      'Entre na sua conta para ver suas sessões.',
    );
  });

  test('traduzir duas vezes não muda a mensagem', () {
    final once = _from('unavailable');
    expect(SessionsFailure.from(once), same(once));
  });
}
