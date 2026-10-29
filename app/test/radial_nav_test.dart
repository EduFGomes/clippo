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

void main() {
  testWidgets('fechada, a roda não mostra as seções', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(ClippoRadialNav(
      items: _destinos,
      currentIndex: 0,
      onSelected: (_) {},
    )));
    await tester.pumpAndSettle();

    // Os rótulos existem na árvore, mas invisíveis (opacidade 0) até abrir.
    expect(find.text('Toque ou arraste até uma seção'), findsOneWidget);
    final hint = tester.widget<FadeTransition>(
      find.ancestor(
        of: find.text('Toque ou arraste até uma seção'),
        matching: find.byType(FadeTransition),
      ).first,
    );
    expect(hint.opacity.value, 0);
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

    final hint = tester.widget<FadeTransition>(
      find.ancestor(
        of: find.text('Toque ou arraste até uma seção'),
        matching: find.byType(FadeTransition),
      ).first,
    );
    expect(hint.opacity.value, 1);
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
