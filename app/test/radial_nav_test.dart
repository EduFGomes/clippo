import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_radial_nav.dart';

const List<ClippoRadialNavItem> _destinos = [
  ClippoRadialNavItem(label: 'Início', icon: 'home'),
  ClippoRadialNavItem(label: 'Gravar', icon: 'capture'),
  ClippoRadialNavItem(label: 'Amigos', icon: 'friends'),
  ClippoRadialNavItem(label: 'Perfil', icon: 'profile'),
];

Widget _app(Widget nav, {Brightness brightness = Brightness.dark}) => MaterialApp(
      theme: clippoTheme(brightness),
      home: Scaffold(body: Stack(children: [const SizedBox.expand(), nav])),
    );

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

double _opacidadeDaSecao(WidgetTester tester, String nome) => tester
    .widget<Opacity>(find.ancestor(of: find.text(nome), matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  testWidgets('fechada, a roda não mostra as seções', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: (_) {},
    )));
    await tester.pumpAndSettle();

    // As seções existem na árvore, mas invisíveis (opacidade 0) até abrir.
    expect(_opacidadeDaSecao(tester, 'Amigos'), 0);
  });

  testWidgets('tocar no botão abre a roda', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: (_) {},
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();

    expect(_opacidadeDaSecao(tester, 'Amigos'), 1);
  });

  testWidgets('escolher uma seção avisa quem está ouvindo', (tester) async {
    await _phone(tester);
    final escolhidos = <int>[];
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: escolhidos.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ClippoRadialNav.itemKey(2)));
    await tester.pumpAndSettle();

    expect(escolhidos, [2]);
  });

  testWidgets('escolher a seção em que já estou não navega de novo', (tester) async {
    await _phone(tester);
    final escolhidos = <int>[];
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: escolhidos.add,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClippoRadialNav.itemKey(0)));
    await tester.pumpAndSettle();

    expect(escolhidos, isEmpty);
  });

  testWidgets('arrastar do botão até uma seção e soltar escolhe a seção', (tester) async {
    await _phone(tester);
    final escolhidos = <int>[];
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: escolhidos.add,
    )));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ClippoRadialNav.buttonKey)));
    await tester.pumpAndSettle();
    final alvo = tester.getCenter(find.byKey(ClippoRadialNav.itemKey(3)));
    // Vários passos, como um dedo de verdade: a lente segue o caminho.
    final inicio = tester.getCenter(find.byKey(ClippoRadialNav.buttonKey));
    for (var k = 1; k <= 6; k++) {
      await gesture.moveTo(Offset.lerp(inicio, alvo, k / 6)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    // O balão acima do dedo mostra a seção sob ele.
    expect(find.byKey(ClippoRadialNav.previewKey), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(ClippoRadialNav.previewKey), matching: find.text('Perfil')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(escolhidos, [3]);
  });

  testWidgets('arrastar e voltar para o botão cancela sem navegar', (tester) async {
    await _phone(tester);
    final escolhidos = <int>[];
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: escolhidos.add,
    )));
    await tester.pumpAndSettle();

    final inicio = tester.getCenter(find.byKey(ClippoRadialNav.buttonKey));
    final gesture = await tester.startGesture(inicio);
    await tester.pumpAndSettle();
    await gesture.moveTo(tester.getCenter(find.byKey(ClippoRadialNav.itemKey(2))));
    await tester.pump();
    await gesture.moveTo(inicio);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(escolhidos, isEmpty);
  });

  testWidgets('segurar uma seção mostra o balão; deslizar para outra troca o balão', (tester) async {
    await _phone(tester);
    final escolhidos = <int>[];
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: escolhidos.add,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ClippoRadialNav.itemKey(1))));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(ClippoRadialNav.previewKey), matching: find.text('Gravar')),
      findsOneWidget,
    );

    // Entre dois ícones o dedo não está em cima de nenhum: o balão some.
    final entre = Offset.lerp(
      tester.getCenter(find.byKey(ClippoRadialNav.itemKey(1))),
      tester.getCenter(find.byKey(ClippoRadialNav.itemKey(2))),
      0.5,
    )!;
    await gesture.moveTo(entre);
    await tester.pumpAndSettle();
    final balao = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byKey(ClippoRadialNav.previewKey),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(balao.opacity.value, 0);

    await gesture.moveTo(tester.getCenter(find.byKey(ClippoRadialNav.itemKey(2))));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byKey(ClippoRadialNav.previewKey), matching: find.text('Amigos')),
      findsOneWidget,
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(escolhidos, [2]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('abre sem erro no tema $brightness', (tester) async {
      await _phone(tester);
      await tester.pumpWidget(_app(
        ClippoRadialNav(items: _destinos, currentIndex: 2, onSelected: (_) {}),
        brightness: brightness,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
