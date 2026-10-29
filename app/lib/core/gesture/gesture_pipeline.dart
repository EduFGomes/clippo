/// Liga as peças da detecção: quadro da câmera → quem é quem → regra (um quadro, cada pessoa) →
/// disparo (o tempo).
///
/// É o que as telas usam: o laboratório mostra cada observação, e a Gravação só se importa com
/// as que disparam.
library;

import 'package:clippo/core/camera/pose_frame.dart';

import 'gesture_rule.dart';
import 'gesture_trigger.dart';
import 'person_tracker.dart';

/// O que a regra disse de uma pessoa do quadro.
class PersonObservation {
  const PersonObservation({required this.id, required this.person, required this.verdict});

  /// O número da pessoa, o mesmo enquanto ela continuar no quadro (ver PersonTracker).
  final int id;

  final DetectedPerson person;

  final GestureVerdict verdict;
}

/// O que a detecção concluiu sobre um quadro.
class GestureObservation {
  const GestureObservation({required this.frame, required this.people, required this.triggered, this.focus});

  /// O quadro analisado, com os pontos (para desenhar o esqueleto).
  final PoseFrame frame;

  /// Cada pessoa do quadro, na ordem de [PoseFrame.people].
  final List<PersonObservation> people;

  /// true só no quadro em que o gesto disparou: é a hora de salvar o highlight,
  /// com os ~30 s que terminam em `frame.timestamp` (R1).
  final bool triggered;

  /// A pessoa que mais interessa neste quadro: quem disparou, senão quem faz o gesto, senão a
  /// maior (a mais perto). null se não há ninguém.
  final PersonObservation? focus;

  /// O que a regra disse da pessoa em [focus] (ou `noPerson`, se não havia ninguém).
  GestureVerdict get verdict => focus?.verdict ?? const GestureVerdict(GestureCheck.noPerson);
}

class GesturePipeline {
  GesturePipeline({this.rule = const GestureRule(), GestureTrigger? trigger, PersonTracker? tracker})
      : trigger = trigger ?? GestureTrigger(),
        tracker = tracker ?? PersonTracker();

  final GestureRule rule;
  final GestureTrigger trigger;
  final PersonTracker tracker;

  /// Um passo: avalia cada pessoa do quadro e atualiza o disparo.
  GestureObservation observe(PoseFrame frame) {
    final ids = tracker.assign(frame.timestamp, [for (final person in frame.people) person.bounds]);
    final people = <PersonObservation>[];
    PersonObservation? fired;
    for (var i = 0; i < frame.people.length; i++) {
      final pose = frame.people[i].bodyPose;
      // Achada pelo detector, mas sem pontos: para a regra, é como ter pontos sem confiança.
      final verdict = pose == null ? const GestureVerdict(GestureCheck.lowConfidence) : rule.evaluate(pose);
      final observation = PersonObservation(id: ids[i], person: frame.people[i], verdict: verdict);
      people.add(observation);
      // Toda pessoa passa pelo disparo, até sem gesto: quem decide o que fazer com isso é o
      // GestureTrigger, e não o pipeline. Depois de um disparo, a espera barra os outros.
      if (trigger.add(frame.timestamp, verdict, person: ids[i])) fired = observation;
    }
    return GestureObservation(
      frame: frame,
      people: people,
      triggered: fired != null,
      focus: fired ?? _mostInteresting(people),
    );
  }

  /// Aplica [observe] a cada quadro do fluxo. Erros do fluxo (câmera, análise) passam direto.
  Stream<GestureObservation> watch(Stream<PoseFrame> frames) => frames.map(observe);

  /// Esquece o disparo e as pessoas, para uma sessão de gravação nova.
  void reset() {
    trigger.reset();
    tracker.reset();
  }

  static PersonObservation? _mostInteresting(List<PersonObservation> people) {
    if (people.isEmpty) return null;
    for (final p in people) {
      if (p.verdict.isGesture) return p;
    }
    double area(PersonObservation p) {
      final bounds = p.person.bounds;
      return bounds == null ? 0 : bounds.width * bounds.height;
    }

    return people.reduce((a, b) => area(b) > area(a) ? b : a);
  }
}
