import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app_shell.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_radial_nav.dart';

Widget _app(Widget home) {
  return MaterialApp(
    theme: clippoTheme(Brightness.dark),
    home: home,
  );
}

void main() {
  testWidgets('navega entre Início, Amigos, Perfil e abre Sessão e Player', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const AppShell()));
    await tester.pumpAndSettle();

    // Começa na Início mostrando as sessões.
    expect(find.text('SUAS\nSESSÕES.'), findsOneWidget);
    expect(find.text('Pelada de quinta'), findsOneWidget);

    // Abre a tela da Sessão a partir da Início.
    await tester.tap(find.text('Ver highlights'));
    await tester.pumpAndSettle();

    expect(find.text('PELADA DE\nQUINTA.'), findsOneWidget);
    expect(find.text('Jogada de cinema'), findsOneWidget);

    // Abre o Player ao tocar num highlight.
    await tester.tap(find.text('Jogada de cinema'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 6'), findsOneWidget);

    // Volta para Sessão e depois para a Início.
    await tester.tap(find.bySemanticsLabel('Fechar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sessões'));
    await tester.pumpAndSettle();
    expect(find.text('SUAS\nSESSÕES.'), findsOneWidget);

    // Abre a roda de navegação e vai para Amigos (índice 2).
    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClippoRadialNav.itemKey(2)));
    await tester.pumpAndSettle();
    expect(find.text('SEUS\nAMIGOS.'), findsOneWidget);

    // Abre a roda de navegação e vai para Perfil (índice 3).
    await tester.tap(find.byKey(ClippoRadialNav.buttonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ClippoRadialNav.itemKey(3)));
    await tester.pumpAndSettle();
    expect(find.text('Gustavo Rocha'), findsWidgets);
  });

  testWidgets('a lista rola até o fim da tela, por trás da roda, sem faixa cortando', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const AppShell()));
    await tester.pumpAndSettle();

    // A área rolável vai até a base da tela; a folga da roda é espaço no fim da lista.
    final scroll = find.byType(SingleChildScrollView).first;
    expect(tester.getBottomLeft(scroll).dy, 915);
    final padding = tester.widget<SingleChildScrollView>(scroll).padding! as EdgeInsets;
    expect(padding.bottom, ClippoSpace.screenBottom + ClippoSize.navClearance);
  });

  testWidgets('com o teclado aberto a roda some e a folga dela também', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const AppShell()));
    await tester.pumpAndSettle();
    expect(find.byKey(ClippoRadialNav.buttonKey), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(find.byKey(ClippoRadialNav.buttonKey), findsNothing);
    final scroll = find.byType(SingleChildScrollView).first;
    final padding = tester.widget<SingleChildScrollView>(scroll).padding! as EdgeInsets;
    expect(padding.bottom, ClippoSpace.screenBottom);
    // O conteúdo termina em cima do teclado, não numa faixa vazia.
    expect(tester.getBottomLeft(scroll).dy, 915 - 300);
  });
}
