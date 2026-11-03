import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/friends/screens/friends_screen.dart';

Widget _app(
  Widget home, {
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: clippoTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

void main() {
  testWidgets('mostra convites pendentes, aceita convite e filtra busca de amigos',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const FriendsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('SEUS\nAMIGOS.'), findsOneWidget);
    expect(find.text('Convites pendentes'), findsOneWidget);
    expect(find.text('Diego Souza'), findsOneWidget);
    expect(find.text('Rafa Costa'), findsOneWidget);
    expect(find.text('@rafa.costa · 12 sessões juntos'), findsOneWidget);

    // Aceitar convite de Diego move para a lista de amigos.
    await tester.tap(find.bySemanticsLabel('Aceitar convite de Diego Souza'));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);

    // Buscar filtra amigos e usuários do diretório.
    await tester.enterText(find.byType(TextField).first, 'Pedro');
    await tester.pumpAndSettle();

    expect(find.text('Pedro Rocha'), findsOneWidget);
    expect(find.text('Rafa Costa'), findsNothing);
  });

  testWidgets('perfil de amigo mostra as sessões que participaram juntos embaixo',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(const FriendsScreen(initialPendingInvites: [])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rafa Costa'));
    await tester.pumpAndSettle();

    expect(find.text('PERFIL DE\nRAFA.'), findsOneWidget);
    expect(find.text('Sessões juntos'), findsOneWidget);
    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('Beach Tennis de sábado'), findsOneWidget);
    expect(find.text('Vôlei de domingo'), findsOneWidget);
  });

  testWidgets('botão Convidar mostra apenas o link simulado para baixar o app',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const FriendsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Convidar amigo'));
    await tester.pumpAndSettle();

    expect(find.text('CONVIDAR\nPRO CLIPPO.'), findsOneWidget);
    expect(find.text('https://clippo.app/baixar'), findsOneWidget);
    expect(find.text('Copiar link para baixar o app'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
      'aba Sessões entra direto quando é aberta e pede permissão quando é fechada',
      (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const FriendsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Sessões'));
    await tester.pumpAndSettle();

    expect(find.text('Entrar em uma sessão'), findsOneWidget);
    expect(find.text('Beach Tennis de sábado'), findsOneWidget);
    expect(find.text('Vôlei de terça'), findsOneWidget);
    expect(find.text('Aberta'), findsNWidgets(2));
    expect(find.text('Fechada'), findsOneWidget);
    expect(find.text('Pedir para entrar'), findsOneWidget);

    // Validar campo vazio de código/link.
    await tester.tap(find.text('Entrar na sessão').first);
    await tester.pump();
    expect(find.text('Informe o código ou link da sessão.'), findsOneWidget);

    // Sessão aberta (BEACH-SAB): entra direto.
    await tester.enterText(find.byType(TextField).first, 'BEACH-SAB');
    await tester.tap(find.text('Entrar na sessão').first);
    await tester.pumpAndSettle();
    expect(find.text('Você entrou em Beach Tennis de sábado.'), findsOneWidget);

    // Sessão fechada (VOLEI-TER): pede permissão ao criador.
    await tester.ensureVisible(find.text('Pedir para entrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pedir para entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Aguardando permissão de Alice Prado'), findsOneWidget);
    expect(
      find.text(
        'Sessão fechada: pedido enviado para Alice Prado liberar sua entrada em Vôlei de terça.',
      ),
      findsOneWidget,
    );
  });

  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            const FriendsScreen(),
            brightness: brightness,
            textScale: scale,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
