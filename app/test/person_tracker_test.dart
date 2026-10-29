import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/gesture/person_tracker.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  const left = Rect.fromLTWH(100, 400, 150, 400);
  const right = Rect.fromLTWH(500, 400, 150, 400);

  test('a mesma pessoa mantém o número, mesmo com o detector trocando a ordem', () {
    final tracker = PersonTracker();
    final first = tracker.assign(_ms(0), [left, right]);
    final second = tracker.assign(_ms(100), [right.translate(10, 0), left.translate(-5, 5)]);
    expect(second, [first[1], first[0]]);
  });

  test('quem chega ganha um número novo, sem mexer nos outros', () {
    final tracker = PersonTracker();
    final [a] = tracker.assign(_ms(0), [left]);
    final [b, c] = tracker.assign(_ms(100), [left, right]);
    expect(b, a);
    expect(c, isNot(a));
  });

  test('duas caixas não ficam com o mesmo número', () {
    final tracker = PersonTracker();
    final [a] = tracker.assign(_ms(0), [left]);
    // As duas se sobrepõem à de antes: a mais parecida fica com o número.
    final ids = tracker.assign(_ms(100), [left.translate(40, 0), left]);
    expect(ids[1], a);
    expect(ids[0], isNot(a));
  });

  test('quem some por mais de 1 s é esquecido', () {
    final tracker = PersonTracker();
    final [a] = tracker.assign(_ms(0), [left]);
    expect(tracker.assign(_ms(900), [left]), [a]);
    tracker.assign(_ms(1000), []);
    expect(tracker.assign(_ms(2000), [left]), isNot([a]));
  });

  test('sem posição, sempre um número novo', () {
    final tracker = PersonTracker();
    final [a] = tracker.assign(_ms(0), [null]);
    final [b] = tracker.assign(_ms(100), [null]);
    expect(b, isNot(a));
  });

  test('reset recomeça os números', () {
    final tracker = PersonTracker()..assign(_ms(0), [left, right]);
    tracker.reset();
    expect(tracker.assign(_ms(100), [right]), [0]);
  });
}
