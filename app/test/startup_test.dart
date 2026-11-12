import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';

Widget _app(Widget home) => MaterialApp(theme: clippoTheme(Brightness.dark), home: home);

void main() {
  testWidgets('abrindo: vinho com o CLIPPO, não um círculo sobre branco', (tester) async {
    await tester.pumpWidget(_app(const StartupLoading()));
    expect(find.text('CLIPPO'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, ClippoBrand.wine);
  });

  testWidgets('primeira vez sem internet: explica, tenta de novo e entra quando conecta',
      (tester) async {
    var online = false;
    var asked = 0;
    await tester.pumpWidget(_app(ProfileGate(
      uid: 'alice',
      hasProfile: (uid) async {
        asked++;
        if (!online) throw const ProfileOfflineException();
        return true;
      },
      signOut: () async {},
      app: const Text('APP ABERTO'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('SEM\nINTERNET.'), findsOneWidget);
    expect(find.textContaining('primeira vez neste celular'), findsOneWidget);

    online = true;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(asked, 2);
    expect(find.text('APP ABERTO'), findsOneWidget);
  });

  testWidgets('erro que não é de internet: frase geral e dá para sair da conta', (tester) async {
    var signedOut = 0;
    await tester.pumpWidget(_app(ProfileGate(
      uid: 'alice',
      hasProfile: (uid) async => throw StateError('servidor'),
      signOut: () async => signedOut++,
      app: const Text('APP ABERTO'),
    )));
    await tester.pumpAndSettle();

    expect(find.text('NÃO DEU\nPARA ABRIR.'), findsOneWidget);
    await tester.tap(find.text('Sair da conta'));
    await tester.pump();
    expect(signedOut, 1);
  });
}
