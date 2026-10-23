/// Liga as peças da detecção: quadro da câmera → regra (um quadro) → disparo (o tempo).
///
/// É o que as telas usam: o laboratório mostra cada observação, e a Gravação só se importa com
/// as que disparam.
library;

import 'package:clippo/core/camera/pose_frame.dart';

import 'gesture_rule.dart';
import 'gesture_trigger.dart';

/// O que a detecção concluiu sobre um quadro.
class GestureObservation {
  const GestureObservation({required this.frame, required this.verdict, required this.triggered});

  /// O quadro analisado, com os 33 pontos (para desenhar o esqueleto).
  final PoseFrame frame;

  /// O que a regra disse deste quadro (ou `noPerson`, se não havia ninguém).
  final GestureVerdict verdict;

  /// true só no quadro em que o gesto disparou: é a hora de salvar o highlight,
  /// com os ~30 s que terminam em `frame.timestamp` (R1).
  final bool triggered;
}

class GesturePipeline {
  GesturePipeline({this.rule = const GestureRule(), GestureTrigger? trigger}) : trigger = trigger ?? GestureTrigger();

  final GestureRule rule;
  final GestureTrigger trigger;

  /// Um passo: avalia o quadro e atualiza o disparo.
  GestureObservation observe(PoseFrame frame) {
    final pose = frame.bodyPose;
    final verdict = pose == null ? const GestureVerdict(GestureCheck.noPerson) : rule.evaluate(pose);
    // Todo quadro vai para o disparo, até os sem gesto: quem decide o que fazer com eles é o
    // GestureTrigger (hoje, nada), e não o pipeline.
    final triggered = trigger.add(frame.timestamp, verdict);
    return GestureObservation(frame: frame, verdict: verdict, triggered: triggered);
  }

  /// Aplica [observe] a cada quadro do fluxo. Erros do fluxo (câmera, análise) passam direto.
  Stream<GestureObservation> watch(Stream<PoseFrame> frames) => frames.map(observe);

  /// Esquece o disparo, para uma sessão de gravação nova.
  void reset() => trigger.reset();
}
