/// O disparo do gesto (glossário: `trigger`): transforma a sequência de quadros em "salve agora".
///
/// A `GestureRule` olha um quadro só; aqui entra o tempo:
/// - o gesto precisa durar um pouco, para um braço que passa pelo Y de relance não disparar;
/// - um quadro perdido no meio (o modelo piscou) não zera a contagem;
/// - depois de um disparo, o mesmo braço levantado não dispara de novo, e um gesto novo só vale
///   depois da espera (R4).
library;

import 'gesture_rule.dart';

/// Os tempos do disparo, juntos para serem calibrados.
///
/// 🟡 Valores iniciais. A espera de 5 s é a sugestão da R4, ainda não confirmada pelo grupo.
class GestureTriggerTimings {
  const GestureTriggerTimings({
    this.hold = const Duration(milliseconds: 400),
    this.maxGap = const Duration(milliseconds: 250),
    this.cooldown = const Duration(seconds: 5),
  });

  /// Quanto tempo o gesto precisa ser visto para disparar. É tempo, e não número de quadros,
  /// porque o modelo de pose não analisa sempre no mesmo ritmo (muda com o celular e a luz).
  final Duration hold;

  /// Maior intervalo sem o gesto que ainda conta como "o mesmo gesto continuando".
  final Duration maxGap;

  /// Depois de um disparo, por quanto tempo nenhum outro vale (R4).
  final Duration cooldown;
}

class GestureTrigger {
  GestureTrigger([this.timings = const GestureTriggerTimings()]);

  final GestureTriggerTimings timings;

  /// Quando começou a sequência atual de quadros com o gesto.
  Duration? _streakStart;

  /// O último quadro em que o gesto apareceu.
  Duration? _lastMatch;

  /// Se a sequência atual já disparou: o mesmo braço levantado não dispara duas vezes.
  bool _streakFired = false;

  /// Quando foi o último disparo, para contar a espera.
  Duration? _lastTrigger;

  /// Recebe o resultado da regra para um quadro e devolve `true` se este é o momento de salvar.
  ///
  /// [timestamp] é a hora do quadro na câmera, sempre crescente. Ela vem de fora (em vez de
  /// `DateTime.now()`) para os testes poderem simular segundos de jogo sem esperar, e porque a
  /// hora em que o quadro foi FILMADO é a que importa para o buffer, não a hora em que a
  /// análise terminou.
  bool add(Duration timestamp, GestureVerdict verdict) {
    // Quadros sem o gesto não mudam nada aqui: o "buraco" que eles formam é medido no
    // próximo quadro com o gesto, comparando com _lastMatch.
    if (!verdict.isGesture) return false;

    final lastMatch = _lastMatch;
    if (lastMatch == null || timestamp - lastMatch > timings.maxGap) {
      _streakStart = timestamp;
      _streakFired = false;
    }
    _lastMatch = timestamp;

    if (_streakFired) return false;
    if (timestamp - _streakStart! < timings.hold) return false;

    final lastTrigger = _lastTrigger;
    if (lastTrigger != null && timestamp - lastTrigger < timings.cooldown) return false;

    _streakFired = true;
    _lastTrigger = timestamp;
    return true;
  }

  /// Esquece tudo, para uma sessão de gravação nova.
  void reset() {
    _streakStart = null;
    _lastMatch = null;
    _streakFired = false;
    _lastTrigger = null;
  }
}
