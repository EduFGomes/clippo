import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/session.dart';

// O documento sessions/{id} como o Firestore devolve, descrito em
// docs/arquitetura.md › Modelo de dados.
Map<String, dynamic> _doc({
  List<String> participantIds = const ['alice', 'bob'],
  List<Map<String, dynamic>>? preview,
  int? participantCount,
  Object? startedAt,
  Object? endedAt,
  Object? location,
}) {
  return <String, dynamic>{
    'name': 'Pelada de quinta',
    'ownerId': 'alice',
    'participantIds': participantIds,
    'participantsPreview': preview ??
        const [
          {'uid': 'alice', 'name': 'Alice Prado', 'photoUrl': 'https://exemplo/a.jpg'},
          {'uid': 'bob', 'name': 'Bob', 'photoUrl': null},
        ],
    'participantCount': participantCount ?? participantIds.length,
    'startedAt': startedAt ?? Timestamp.fromDate(DateTime.utc(2026, 9, 11, 19, 30)),
    'endedAt': endedAt,
    'durationSeconds': 6120,
    'location': location,
    'highlightCount': 7,
  };
}

void main() {
  group('Session.fromMap', () {
    test('lê o documento inteiro', () {
      final session = Session.fromMap('quinta', _doc(
        endedAt: Timestamp.fromDate(DateTime.utc(2026, 9, 11, 21, 12)),
        location: const {'label': 'Quadra do Parque', 'lat': -23.5, 'lng': -46.6},
      ));

      expect(session.id, 'quinta');
      expect(session.name, 'Pelada de quinta');
      // Timestamp.toDate() devolve hora LOCAL, que é a que a tela mostra
      // ("19:30 – 21:12" é o horário de quem jogou). Por isso compara-se o
      // instante, não o fuso: o == de DateTime também olha o isUtc.
      expect(session.startedAt.isAtSameMomentAs(DateTime.utc(2026, 9, 11, 19, 30)), isTrue);
      expect(session.endedAt!.isAtSameMomentAs(DateTime.utc(2026, 9, 11, 21, 12)), isTrue);
      expect(session.duration, const Duration(hours: 1, minutes: 42));
      expect(session.highlightCount, 7);
      expect(session.location?.label, 'Quadra do Parque');
      expect(session.location?.latitude, -23.5);
      expect(session.participants.first.name, 'Alice Prado');
      expect(session.participants.first.firstName, 'Alice');
    });

    test('quem gravou é o dono (R9)', () {
      final session = Session.fromMap('quinta', _doc());
      expect(session.isOwnedBy('alice'), isTrue);
      expect(session.isOwnedBy('bob'), isFalse);
    });

    test('sessão sem local, sem fim e sem avatares não quebra', () {
      final session = Session.fromMap('quinta', _doc(preview: const []));
      expect(session.location, isNull);
      expect(session.endedAt, isNull);
      expect(session.participants, isEmpty);
    });

    test('documento vazio vira sessão neutra, sem estourar', () {
      final session = Session.fromMap('torta', const {});
      expect(session.name, isEmpty);
      expect(session.participantIds, isEmpty);
      expect(session.participantCount, 0);
      expect(session.highlightCount, 0);
      expect(session.duration, Duration.zero);
      // Sem data, a sessão vai para o FIM da lista, nunca para o topo.
      expect(session.startedAt.millisecondsSinceEpoch, 0);
    });

    test('o total de participantes vem do contador, não da cópia', () {
      final session = Session.fromMap('quinta', _doc(
        participantIds: const ['alice', 'bob'],
        participantCount: 10,
      ));
      expect(session.participantCount, 10);
      expect(session.participants.length, 2);
    });
  });

  group('avatares da lista', () {
    List<Map<String, dynamic>> preview(int n) =>
        [for (var i = 0; i < n; i++) {'uid': 'u$i', 'name': 'Pessoa $i'}];

    test('mostra até 5 e conta o resto como +N', () {
      final session = Session.fromMap('quinta', _doc(preview: preview(8), participantCount: 10));
      expect(session.visibleParticipants().length, 5);
      expect(session.hiddenParticipantCount(), 5);
    });

    test('com 5 ou menos não sobra ninguém', () {
      final session = Session.fromMap('quinta', _doc(preview: preview(3), participantCount: 3));
      expect(session.visibleParticipants().length, 3);
      expect(session.hiddenParticipantCount(), 0);
    });
  });
}
