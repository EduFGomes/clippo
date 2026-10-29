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
/// 🟡 Valores iniciais, menos a espera de 5 s (R4, decidida pelo grupo em 28/10/2026).
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

  /// A sequência de gesto de cada pessoa (pelo número do PersonTracker): o tempo mínimo é
  /// contado por pessoa, para dois braços de pessoas diferentes não somarem um gesto.
  final Map<Object, _Streak> _streaks = {};

  /// Quando foi o último disparo, para contar a espera. É uma só para a quadra inteira: o
  /// highlight salvo já tem os 30 s de todo mundo (R4).
  Duration? _lastTrigger;

  /// Recebe o resultado da regra para um quadro e devolve `true` se este é o momento de salvar.
  ///
  /// [timestamp] é a hora do quadro na câmera, sempre crescente. Ela vem de fora (em vez de
  /// `DateTime.now()`) para os testes poderem simular segundos de jogo sem esperar, e porque a
  /// hora em que o quadro foi FILMADO é a que importa para o buffer, não a hora em que a
  /// análise terminou. [person] diz de quem é o resultado (com uma pessoa só, deixe o padrão).
  bool add(Duration timestamp, GestureVerdict verdict, {Object person = 0}) {
    // Quem não faz o gesto há mais que maxGap já recomeçaria do zero: pode ser esquecido.
    _streaks.removeWhere((_, streak) => timestamp - streak.lastMatch > timings.maxGap);

    // Quadros sem o gesto não mudam nada aqui: o "buraco" que eles formam é medido no
    // próximo quadro com o gesto, comparando com lastMatch.
    if (!verdict.isGesture) return false;

    final streak = _streaks[person] ??= _Streak(timestamp);
    streak.lastMatch = timestamp;

    // O mesmo braço levantado não dispara duas vezes.
    if (streak.fired) return false;
    if (timestamp - streak.start < timings.hold) return false;

    final lastTrigger = _lastTrigger;
    if (lastTrigger != null && timestamp - lastTrigger < timings.cooldown) return false;

    streak.fired = true;
    _lastTrigger = timestamp;
    return true;
  }

  /// Esquece tudo, para uma sessão de gravação nova.
  void reset() {
    _streaks.clear();
    _lastTrigger = null;
  }
}

/// Uma sequência de quadros com o gesto, de uma pessoa.
class _Streak {
  _Streak(this.start) : lastMatch = start;

  /// Quando começou.
  final Duration start;

  /// O último quadro em que o gesto apareceu.
  Duration lastMatch;

  /// Se esta sequência já disparou.
  bool fired = false;
}
