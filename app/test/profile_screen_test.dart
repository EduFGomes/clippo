import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';
import 'package:clippo/features/profile/widgets/profile_settings_tile.dart';

Widget _app(Widget home, {Brightness brightness = Brightness.light, double textScale = 1}) {
  return MaterialApp(
    theme: clippoTheme(brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: home,
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Perfil abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        await _phone(tester);
        await tester.pumpWidget(_app(const ProfileScreen(), brightness: brightness, textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('textos e estatísticas do Perfil seguem o design', (tester) async {
    var signedOut = false;
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(onSignOut: () => signedOut = true)));

    expect(find.text('SEU\nPERFIL.'), findsOneWidget);
    expect(find.text('Editar foto'), findsOneWidget);
    expect(find.text('sessões'), findsOneWidget);
    expect(find.text('highlights'), findsOneWidget);
    expect(find.text('amigos'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Nome'), findsOneWidget);
    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pump();
    expect(signedOut, isTrue);
  });

  testWidgets('alterna notificações ao tocar na linha', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const ProfileScreen()));

    bool isEnabled() => tester.widget<ProfileToggleTile>(find.byType(ProfileToggleTile)).value;
    expect(isEnabled(), isTrue);

    await tester.tap(find.text('Notificações'));
    await tester.pumpAndSettle();
    expect(isEnabled(), isFalse);
  });

  testWidgets('edição de nome e usuário valida com input_validation antes de salvar', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const ProfileScreen()));

    // Editar nome: tenta salvar vazio e depois corrige
    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(find.text('SEU\nNOME.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Laura Suzuki');
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Laura Suzuki'), findsNWidgets(2)); // cabeçalho + linha Nome

    // Editar @usuário: tenta salvar com ".." e depois corrige
    await tester.tap(find.text('Usuário'));
    await tester.pumpAndSettle();
    expect(find.text('SEU\nUSUÁRIO.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laura..suzuki');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(find.text('O ponto não pode ficar no começo, no fim ou repetido.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laura.suzuki');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('@laura.suzuki'), findsNWidgets(2)); // cabeçalho + linha Usuário
  });
}
