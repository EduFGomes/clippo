import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/validation/input_validation.dart';

// Os mesmos casos de backend/functions/test/friends.validation.test.ts e
// sessions.merge.test.ts: as duas regras precisam concordar (regra 0 do AGENTS.md).
void main() {
  Session sessao(
    String id, {
    String owner = 'ana',
    List<String> participants = const ['ana', 'beto'],
    required DateTime start,
    Duration duration = const Duration(hours: 1),
    String? mergedInto,
  }) =>
      Session(
        id: id,
        name: id,
        ownerId: owner,
        participantIds: participants,
        participants: const [],
        participantCount: participants.length,
        startedAt: start,
        endedAt: start.add(duration),
        duration: duration,
        highlightCount: 0,
        mergedInto: mergedInto,
      );

  group('validação de amigos e de juntar sessões', () {
    test('uid do Auth passa; caminho e vazio não', () {
      expect(validateUid('Xy12abcDEF34ghiJKL56mnoPQR78'), isNull);
      for (final ruim in ['', 'a/b', 'alice_bob', '../users']) {
        expect(validateUid(ruim), 'Não encontramos essa pessoa.');
      }
    });

    test('id do pedido de juntar: duas sessões separadas por "__"', () {
      expect(validateMergeRequestId('sessaoA01__sessaoB01'), isNull);
      expect(validateMergeRequestId('sessaoA01'), 'Esse pedido não existe mais.');
      expect(validateMergeRequestId('sessaoA01__sessaoB01__x'), 'Esse pedido não existe mais.');
      expect(validateMergeRequestId('a__sessaoB01'), 'Não foi possível salvar a sessão. Tente de novo.');
    });
  });

  group('FriendsRepository — nada vai para o servidor sem validar', () {
    test('@ inválido barra antes de chamar a Function', () async {
      var chamou = false;
      final repo = FriendsRepository(callFunction: (name, payload) async {
        chamou = true;
        return {};
      });
      await expectLater(
        repo.sendFriendRequest('a b'),
        throwsA(isA<FriendsFailure>()
            .having((f) => f.message, 'message', 'Use só letras sem acento, números, "_" e ".".')
            .having((f) => f.code, 'code', 'username')),
      );
      expect(chamou, isFalse);
    });

    test('manda o @ normalizado e devolve a situação', () async {
      Map<String, dynamic>? enviado;
      final repo = FriendsRepository(callFunction: (name, payload) async {
        expect(name, 'sendFriendRequest');
        enviado = payload;
        return {'uid': 'beto', 'status': 'accepted'};
      });
      expect(await repo.sendFriendRequest('  @Beto.Lins '), FriendshipStatus.accepted);
      expect(enviado, {'username': 'beto.lins'});
    });

    test('a mensagem do servidor chega à tela com o campo', () async {
      final repo = FriendsRepository(callFunction: (name, payload) async {
        throw FirebaseFunctionsException(
          code: 'not-found',
          message: 'Não achamos ninguém com esse @.',
          details: {'field': 'username'},
        );
      });
      await expectLater(
        repo.sendFriendRequest('ninguem'),
        throwsA(isA<FriendsFailure>()
            .having((f) => f.message, 'message', 'Não achamos ninguém com esse @.')
            .having((f) => f.code, 'code', 'username')),
      );
    });

    test('uid inválido não chama acceptFriendRequest nem removeFriend', () async {
      final repo = FriendsRepository(callFunction: (name, payload) async => fail('não devia chamar'));
      await expectLater(repo.acceptFriendRequest('a/b'), throwsA(isA<FriendsFailure>()));
      await expectLater(repo.removeFriend(''), throwsA(isA<FriendsFailure>()));
    });
  });

  group('Friendship — vista do lado de quem está logado', () {
    final data = {
      'uids': ['ana', 'beto'],
      'status': 'pending',
      'requestedBy': 'beto',
      'requestedTo': 'ana',
      'profiles': {
        'ana': {'name': 'Ana Reis', 'username': 'ana', 'photoUrl': null},
        'beto': {'name': 'Beto Lins', 'username': 'beto', 'photoUrl': null},
      },
    };

    test('a outra pessoa é sempre "other"', () {
      expect(Friendship.fromMap('ana_beto', data, myUid: 'ana').other.name, 'Beto Lins');
      expect(Friendship.fromMap('ana_beto', data, myUid: 'beto').other.name, 'Ana Reis');
    });

    test('pedido recebido para um, enviado para o outro', () {
      expect(Friendship.fromMap('ana_beto', data, myUid: 'ana').isIncomingFor('ana'), isTrue);
      expect(Friendship.fromMap('ana_beto', data, myUid: 'beto').isOutgoingFor('beto'), isTrue);
    });
  });

  group('"X sessões juntos" (R16) e sessões juntadas (D18)', () {
    final dia = DateTime.utc(2026, 11, 2, 10);
    final minhas = [
      sessao('tenis-ana', start: dia),
      sessao('tenis-beto', owner: 'beto', start: dia.subtract(const Duration(minutes: 5))),
      sessao('juntada', owner: 'beto', start: dia, mergedInto: 'tenis-ana'),
      sessao('so-ana', participants: const ['ana'], start: dia),
      sessao('outro-dia', owner: 'beto', start: dia.add(const Duration(days: 1))),
    ];

    test('conta as sessões em que os dois jogaram, sem as juntadas', () {
      expect(FriendsRepository.sessionsTogether('ana', 'beto', minhas), 3);
    });

    test('candidatas a juntar: de outro dono, do mesmo jogo, ainda não juntadas', () {
      final candidatas = SessionsRepository.mergeCandidates(minhas.first, minhas);
      expect(candidatas.map((s) => s.id), ['tenis-beto']);
    });

    test('Session lê mergedInto e mergedFrom do documento', () {
      final s = Session.fromMap('a', {
        'mergedInto': 'principal',
        'mergedFrom': ['b', 'c'],
      });
      expect(s.isMerged, isTrue);
      expect(s.mergedFrom, ['b', 'c']);
      expect(Session.fromMap('x', const {}).isMerged, isFalse);
    });
  });
}
