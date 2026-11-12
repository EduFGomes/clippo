import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/validation/input_validation.dart';

void main() {
  final inicio = DateTime.utc(2026, 10, 29, 22, 30);
  final fim = DateTime.utc(2026, 10, 30, 0, 12);
  final agora = DateTime.utc(2026, 10, 30, 1);

  PendingHighlight lance({
    String id = 'lance-0001',
    String? title,
    Duration offset = const Duration(minutes: 12, seconds: 40),
    Duration duration = const Duration(seconds: 30),
  }) {
    return PendingHighlight(
      highlightId: id,
      localPath: '/data/user/0/com.clippoapp.clippo/files/highlights/$id.mp4',
      offset: offset,
      duration: duration,
      title: title,
    );
  }

  group('SessionsRepository.saveSession — envio e normalização', () {
    test('normaliza os campos e devolve os videoPaths da Function', () async {
      String? calledName;
      Map<String, dynamic>? sentPayload;

      final repo = SessionsRepository(
        callFunction: (name, payload) async {
          calledName = name;
          sentPayload = payload;
          return {
            'sessionId': 'sessao-0001',
            'created': true,
            'videoPaths': {
              'lance-0001': 'sessions/sessao-0001/highlights/lance-0001/video.mp4',
              'lance-0002': 'sessions/sessao-0001/highlights/lance-0002/video.mp4',
            },
          };
        },
      );

      final paths = await repo.saveSession(
        sessionId: 'sessao-0001',
        name: '  Pelada   de quinta ',
        startedAt: inicio,
        endedAt: fim,
        location: '  Quadra   do Parque ',
        participantIds: const ['bob', 'carol', 'bob'],
        highlights: [
          lance(id: 'lance-0001'),
          lance(id: 'lance-0002', title: '  Voleio   do Rafa '),
        ],
        now: agora,
      );

      expect(calledName, 'saveSession');
      expect(sentPayload?['sessionId'], 'sessao-0001');
      expect(sentPayload?['name'], 'Pelada de quinta');
      expect(sentPayload?['location'], 'Quadra do Parque');
      expect(sentPayload?['startedAt'], '2026-10-29T22:30:00.000Z');
      expect(sentPayload?['endedAt'], '2026-10-30T00:12:00.000Z');
      expect(sentPayload?['participantIds'], ['bob', 'carol']);
      expect(sentPayload?['highlights'], [
        {
          'highlightId': 'lance-0001',
          'title': 'Lance 1',
          'offsetSeconds': 760,
          'durationSeconds': 30,
        },
        {
          'highlightId': 'lance-0002',
          'title': 'Voleio do Rafa',
          'offsetSeconds': 760,
          'durationSeconds': 30,
        },
      ]);
      expect(paths, {
        'lance-0001': 'sessions/sessao-0001/highlights/lance-0001/video.mp4',
        'lance-0002': 'sessions/sessao-0001/highlights/lance-0002/video.mp4',
      });
    });
  });

  group('SessionsRepository.saveSession — barra no app antes de chamar o Firebase (regra 0)', () {
    late int calls;
    late SessionsRepository repo;

    setUp(() {
      calls = 0;
      repo = SessionsRepository(
        callFunction: (_, _) async {
          calls++;
          return const {};
        },
      );
    });

    Future<void> expectRejected(
      Future<void> Function() action, {
      required String code,
      required String message,
    }) async {
      await expectLater(
        action,
        throwsA(
          isA<SessionsFailure>()
              .having((e) => e.code, 'code', code)
              .having((e) => e.message, 'message', message),
        ),
      );
      expect(calls, 0, reason: 'não pode chamar a Cloud Function quando a validação falha');
    }

    test('recusa sessionId inválido', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'curto',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          now: agora,
        ),
        code: 'sessionId',
        message: 'Não foi possível salvar a sessão. Tente de novo.',
      );
    });

    test('recusa nome vazio ou longo demais', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: '   ',
          startedAt: inicio,
          endedAt: fim,
          now: agora,
        ),
        code: 'name',
        message: 'Dê um nome para a sessão.',
      );
    });

    test('recusa local acima do limite', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          location: 'a' * (locationMax + 1),
          now: agora,
        ),
        code: 'location',
        message: 'O local pode ter até $locationMax caracteres.',
      );
    });

    test('recusa período inválido', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: fim,
          endedAt: inicio,
          now: agora,
        ),
        code: 'endedAt',
        message: 'O fim da sessão precisa vir depois do início.',
      );
    });

    test('recusa lista de participantes com uid vazio ou acima do limite', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          participantIds: const ['bob', ''],
          now: agora,
        ),
        code: 'participantIds',
        message: 'Confira quem jogou com você.',
      );

      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          participantIds: List<String>.generate(participantsMax + 1, (i) => 'u$i'),
          now: agora,
        ),
        code: 'participantIds',
        message: 'Uma sessão pode ter até $participantsMax participantes.',
      );
    });

    test('recusa título do lance acima de 50 caracteres', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          highlights: [lance(title: 'a' * (highlightTitleMax + 1))],
          now: agora,
        ),
        code: 'highlights',
        message: 'O nome do lance pode ter até $highlightTitleMax caracteres.',
      );
    });

    test('recusa lances com id repetido, momento fora da sessão ou duração inválida', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          highlights: [lance(id: 'lance-0001'), lance(id: 'lance-0001')],
          now: agora,
        ),
        code: 'highlights',
        message: 'Não foi possível salvar os lances.',
      );

      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          highlights: [lance(offset: const Duration(seconds: 6200))],
          now: agora,
        ),
        code: 'highlights',
        message: 'Confira o momento dos lances.',
      );

      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          highlights: [lance(duration: Duration.zero)],
          now: agora,
        ),
        code: 'highlights',
        message: 'Confira a duração dos lances.',
      );
    });

    test('recusa mais de 200 lances', () async {
      await expectRejected(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          highlights: List<PendingHighlight>.generate(
            highlightsMax + 1,
            (i) => lance(id: 'lance-${i.toString().padLeft(4, '0')}'),
          ),
          now: agora,
        ),
        code: 'highlights',
        message: 'Uma sessão pode ter até $highlightsMax lances.',
      );
    });
  });

  group('SessionsRepository.saveSession — tradução de erros do servidor', () {
    test('preserva a mensagem e o details.field da Cloud Function', () async {
      final repo = SessionsRepository(
        callFunction: (_, _) async {
          throw FirebaseFunctionsException(
            code: 'not-found',
            message: 'Alguém da lista não está mais no Clippo.',
            details: const {'field': 'participantIds'},
          );
        },
      );

      await expectLater(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          now: agora,
        ),
        throwsA(
          isA<SessionsFailure>()
              .having((e) => e.message, 'message', 'Alguém da lista não está mais no Clippo.')
              .having((e) => e.code, 'code', 'participantIds'),
        ),
      );
    });

    test('traduz falha de rede do Firebase para mensagem amigável', () async {
      final repo = SessionsRepository(
        callFunction: (_, _) async {
          throw FirebaseException(plugin: 'cloud_functions', code: 'unavailable');
        },
      );

      await expectLater(
        () => repo.saveSession(
          sessionId: 'sessao-0001',
          name: 'Pelada',
          startedAt: inicio,
          endedAt: fim,
          now: agora,
        ),
        throwsA(
          isA<SessionsFailure>().having(
            (e) => e.message,
            'message',
            'Sem internet. Suas sessões aparecem assim que você conectar.',
          ),
        ),
      );
    });
  });

  group('SessionsRepository.renameHighlight — validado no app e no servidor', () {
    test('normaliza o nome e chama a Function com sessão e lance', () async {
      String? calledName;
      Map<String, dynamic>? sent;
      final repo = SessionsRepository(callFunction: (name, payload) async {
        calledName = name;
        sent = payload;
        return {'title': 'Voleio do Rafa'};
      });
      final saved = await repo.renameHighlight(
        sessionId: 'sessao-0001',
        highlightId: 'lance-0001',
        title: '  Voleio  do Rafa ',
      );
      expect(saved, 'Voleio do Rafa');
      expect(calledName, 'renameHighlight');
      expect(sent, {'sessionId': 'sessao-0001', 'highlightId': 'lance-0001', 'title': 'Voleio do Rafa'});
    });

    test('nome vazio ou longo demais nem chega ao servidor', () async {
      var calls = 0;
      final repo = SessionsRepository(callFunction: (_, _) async {
        calls++;
        return const {};
      });
      for (final ruim in ['   ', 'a' * (highlightTitleMax + 1)]) {
        await expectLater(
          repo.renameHighlight(sessionId: 'sessao-0001', highlightId: 'lance-0001', title: ruim),
          throwsA(isA<SessionsFailure>()
              .having((f) => f.code, 'code', 'title')
              .having((f) => f.message, 'message', validateHighlightRename(ruim))),
        );
      }
      await expectLater(
        repo.renameHighlight(sessionId: '../x', highlightId: 'lance-0001', title: 'Golaço'),
        throwsA(isA<SessionsFailure>().having((f) => f.code, 'code', 'sessionId')),
      );
      expect(calls, 0);
    });

    test('a recusa do servidor chega com o campo, para ir embaixo dele', () async {
      final repo = SessionsRepository(callFunction: (_, _) async {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Só quem gravou a sessão renomeia os lances.',
        );
      });
      await expectLater(
        repo.renameHighlight(sessionId: 'sessao-0001', highlightId: 'lance-0001', title: 'Golaço'),
        throwsA(isA<SessionsFailure>()
            .having((f) => f.message, 'message', 'Só quem gravou a sessão renomeia os lances.')),
      );
    });
  });

  group('SessionsRepository.deleteSession — validado no app e no servidor', () {
    test('chama a Function só com o id da sessão', () async {
      String? calledName;
      Map<String, dynamic>? sent;
      final repo = SessionsRepository(callFunction: (name, payload) async {
        calledName = name;
        sent = payload;
        return {'sessionId': 'sessao-0001'};
      });
      await repo.deleteSession('sessao-0001');
      expect(calledName, 'deleteSession');
      expect(sent, {'sessionId': 'sessao-0001'});
    });

    test('id fora do padrão nem chega ao servidor', () async {
      var calls = 0;
      final repo = SessionsRepository(callFunction: (_, _) async {
        calls++;
        return const {};
      });
      await expectLater(
        repo.deleteSession('../x'),
        throwsA(isA<SessionsFailure>().having((f) => f.code, 'code', 'sessionId')),
      );
      expect(calls, 0);
    });

    test('a recusa do servidor chega pronta para a tela', () async {
      final repo = SessionsRepository(callFunction: (_, _) async {
        throw FirebaseFunctionsException(
          code: 'permission-denied',
          message: 'Só quem gravou a sessão pode excluir.',
        );
      });
      await expectLater(
        repo.deleteSession('sessao-0001'),
        throwsA(isA<SessionsFailure>()
            .having((f) => f.message, 'message', 'Só quem gravou a sessão pode excluir.')),
      );
    });
  });

  group('SessionsRepository.deleteHighlight — validado no app e no servidor', () {
    test('chama a Function com a sessão e o lance; ids tortos nem saem do app', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final repo = SessionsRepository(callFunction: (name, payload) async {
        calls.add((name, payload));
        return const {};
      });
      await repo.deleteHighlight(sessionId: 'sessao-0001', highlightId: 'lance-0001');
      expect(calls.single.$1, 'deleteHighlight');
      expect(calls.single.$2, {'sessionId': 'sessao-0001', 'highlightId': 'lance-0001'});
      await expectLater(
        repo.deleteHighlight(sessionId: 'sessao-0001', highlightId: '../x'),
        throwsA(isA<SessionsFailure>().having((f) => f.code, 'code', 'highlightId')),
      );
      expect(calls, hasLength(1));
    });
  });

  group('SessionsRepository.updateSession — data e horário (regra 0)', () {
    final inicio = DateTime.utc(2026, 10, 29, 22, 30);
    final fim = DateTime.utc(2026, 10, 30, 0, 12);
    final agora = DateTime.utc(2026, 10, 30, 1);

    test('manda início e fim juntos, em ISO 8601 UTC', () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final repo = SessionsRepository(callFunction: (name, payload) async {
        calls.add((name, payload));
        return const {};
      });
      await repo.updateSession(
        sessionId: 'sessao-0001',
        startedAt: inicio,
        endedAt: fim,
        highlightOffsets: const [Duration(minutes: 30)],
        now: agora,
      );
      expect(calls.single.$1, 'updateSession');
      expect(calls.single.$2, {
        'sessionId': 'sessao-0001',
        'startedAt': '2026-10-29T22:30:00.000Z',
        'endedAt': '2026-10-30T00:12:00.000Z',
      });
    });

    test('período inválido ou que corta lances nem chega ao servidor', () async {
      var calls = 0;
      final repo = SessionsRepository(callFunction: (_, _) async {
        calls++;
        return const {};
      });
      await expectLater(
        repo.updateSession(sessionId: 'sessao-0001', startedAt: fim, endedAt: inicio, now: agora),
        throwsA(isA<SessionsFailure>()
            .having((f) => f.code, 'code', 'endedAt')
            .having((f) => f.message, 'message', 'O fim da sessão precisa vir depois do início.')),
      );
      await expectLater(
        repo.updateSession(sessionId: 'sessao-0001', startedAt: inicio, now: agora),
        throwsA(isA<SessionsFailure>().having((f) => f.code, 'code', 'endedAt')),
      );
      await expectLater(
        repo.updateSession(
          sessionId: 'sessao-0001',
          startedAt: inicio,
          endedAt: fim,
          highlightOffsets: const [Duration(hours: 2)],
          now: agora,
        ),
        throwsA(isA<SessionsFailure>().having(
          (f) => f.message,
          'message',
          'A sessão precisa durar até o último lance. Confira o horário do fim.',
        )),
      );
      expect(calls, 0);
    });
  });
}
