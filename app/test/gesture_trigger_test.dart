import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/gesture/gesture_rule.dart';
import 'package:clippo/core/gesture/gesture_trigger.dart';

const _yes = GestureVerdict(GestureCheck.matched);
const _no = GestureVerdict(GestureCheck.armNotDiagonal);

/// Simula a câmera mandando um quadro a cada [stepMs] de [fromMs] até [toMs] (incluído).
/// [gestureAt] diz se naquele milissegundo a pessoa está fazendo o gesto.
/// Devolve em que milissegundos o gatilho disparou.
List<int> _run(
  GestureTrigger trigger, {
  required bool Function(int ms) gestureAt,
  int fromMs = 0,
  required int toMs,
  int stepMs = 100,
}) {
  final fired = <int>[];
  for (var ms = fromMs; ms <= toMs; ms += stepMs) {
    if (trigger.add(Duration(milliseconds: ms), gestureAt(ms) ? _yes : _no)) fired.add(ms);
  }
  return fired;
}

void main() {
  test('dispara depois de 400 ms de gesto contínuo', () {
    // Gesto a partir de 1 s: 1000, 1100, 1200, 1300 ainda não; 1400 completa os 400 ms.
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms >= 1000 && ms < 3000, toMs: 3000), [1400]);
  });

  test('não dispara com o gesto curto demais', () {
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms >= 1000 && ms < 1300, toMs: 3000), isEmpty);
  });

  test('não dispara com o modelo "piscando" o gesto em quadros soltos', () {
    // Um quadro com gesto a cada 400 ms: cada um começa uma sequência nova.
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms % 400 == 0, toMs: 5000), isEmpty);
  });

  test('um quadro perdido no meio não zera a contagem', () {
    // O quadro de 1200 falhou, mas o buraco (1100 → 1300 = 200 ms) é menor que 250 ms.
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms >= 1000 && ms < 3000 && ms != 1200, toMs: 3000), [1400]);
  });

  test('um buraco grande recomeça a contagem', () {
    // Sem gesto de 1200 a 1400: o buraco 1100 → 1500 é de 400 ms. A contagem recomeça em 1500.
    bool gesture(int ms) => ms >= 1000 && ms < 3000 && !(ms >= 1200 && ms <= 1400);
    expect(_run(GestureTrigger(), gestureAt: gesture, toMs: 3000), [1900]);
  });

  test('braços levantados por muito tempo disparam uma vez só', () {
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms >= 1000, toMs: 20000), [1400]);
  });

  test('um gesto novo dentro da espera de 5 s não dispara (R4)', () {
    // Primeiro gesto dispara em 1400. O segundo, de 3000 a 3600, cai dentro da espera.
    bool gesture(int ms) => (ms >= 1000 && ms < 2000) || (ms >= 3000 && ms < 3600);
    expect(_run(GestureTrigger(), gestureAt: gesture, toMs: 10000), [1400]);
  });

  test('um gesto novo depois da espera dispara de novo', () {
    bool gesture(int ms) => (ms >= 1000 && ms < 2000) || (ms >= 7000 && ms < 8000);
    expect(_run(GestureTrigger(), gestureAt: gesture, toMs: 10000), [1400, 7400]);
  });

  test('um gesto que começou na espera e continua dispara quando ela acaba', () {
    // Espera vai de 1400 a 6400; o segundo gesto vai de 5000 a 7000.
    bool gesture(int ms) => (ms >= 1000 && ms < 2000) || (ms >= 5000 && ms < 7000);
    expect(_run(GestureTrigger(), gestureAt: gesture, toMs: 10000), [1400, 6400]);
  });

  test('funciona com o modelo analisando mais devagar', () {
    // 4 quadros por segundo: 1000, 1250, 1500 → dispara em 1500 (500 ms ≥ 400 ms).
    expect(_run(GestureTrigger(), gestureAt: (ms) => ms >= 1000 && ms < 3000, toMs: 3000, stepMs: 250), [1500]);
  });

  test('reset esquece a espera e a sequência', () {
    final trigger = GestureTrigger();
    expect(_run(trigger, gestureAt: (ms) => ms >= 1000 && ms < 2000, toMs: 2000), [1400]);
    trigger.reset();
    expect(_run(trigger, gestureAt: (_) => true, fromMs: 2100, toMs: 3000), [2500]);
  });

  test('usa os tempos recebidos', () {
    final trigger = GestureTrigger(const GestureTriggerTimings(hold: Duration(milliseconds: 1000), cooldown: Duration(seconds: 2)));
    bool gesture(int ms) => (ms >= 0 && ms < 1500) || (ms >= 2500 && ms < 4000);
    // 1000 ms de gesto → dispara em 1000. Segundo gesto: começa em 2500, completa em 3500,
    // já fora da espera de 2 s (que acabou em 3000).
    expect(_run(trigger, gestureAt: gesture, toMs: 5000), [1000, 3500]);
  });

  group('várias pessoas', () {
    /// Um quadro a cada 100 ms; [a] e [b] dizem se cada pessoa faz o gesto. Devolve os disparos
    /// como (ms, pessoa).
    List<(int, String)> runTwo({required bool Function(int) a, required bool Function(int) b, required int toMs}) {
      final trigger = GestureTrigger();
      final fired = <(int, String)>[];
      for (var ms = 0; ms <= toMs; ms += 100) {
        final t = Duration(milliseconds: ms);
        if (trigger.add(t, a(ms) ? _yes : _no, person: 'a')) fired.add((ms, 'a'));
        if (trigger.add(t, b(ms) ? _yes : _no, person: 'b')) fired.add((ms, 'b'));
      }
      return fired;
    }

    test('o tempo do gesto é contado por pessoa', () {
      // Cada uma faz 300 ms de gesto, uma logo depois da outra: juntas dariam 600 ms, mas
      // ninguém fez os 400 ms.
      expect(runTwo(a: (ms) => ms >= 1000 && ms < 1300, b: (ms) => ms >= 1300 && ms < 1600, toMs: 3000), isEmpty);
    });

    test('a pessoa de trás do quadro também dispara', () {
      expect(runTwo(a: (_) => false, b: (ms) => ms >= 1000 && ms < 2000, toMs: 3000), [(1400, 'b')]);
    });

    test('a espera de 5 s vale para a quadra inteira (R4)', () {
      // A dispara em 1400; B faz o gesto logo depois, dentro da espera; e de novo depois dela.
      expect(
        runTwo(
          a: (ms) => ms >= 1000 && ms < 2000,
          b: (ms) => (ms >= 2000 && ms < 3000) || (ms >= 7000 && ms < 8000),
          toMs: 10000,
        ),
        [(1400, 'a'), (7400, 'b')],
      );
    });
  });
}
