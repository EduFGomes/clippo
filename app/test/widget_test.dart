import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/dev/screen_catalog.dart';

// Estes testes abrem o catálogo direto, sem Firebase.
// Fluxos que dependem de login são testados no Emulator.
void main() {
  testWidgets('o catálogo de telas abre', (tester) async {
    await tester.pumpWidget(const ClippoApp(home: ScreenCatalog()));
    expect(find.text('Clippo · catálogo de telas'), findsOneWidget);
    expect(find.text('Início'), findsOneWidget);
  });

  testWidgets('tocar numa tela do catálogo abre a tela provisória', (tester) async {
    await tester.pumpWidget(const ClippoApp(home: ScreenCatalog()));
    // A lista só constrói os itens perto da área visível; "Perfil" fica no fim.
    // scrollUntilVisible rola até o item ser construído; ensureVisible termina de trazê-lo
    // para dentro da tela, para o toque acertar.
    await tester.scrollUntilVisible(find.text('Perfil'), 200);
    await tester.ensureVisible(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('SEU\nPERFIL.'), findsOneWidget);
  });

  testWidgets('boas-vindas mostra a frase da marca e leva ao "Como funciona"', (tester) async {
    await tester.pumpWidget(const ClippoApp(home: ScreenCatalog()));
    await tester.tap(find.text('Boas-vindas'));
    await tester.pumpAndSettle();
    expect(find.text('LEVANTOU OS BRAÇOS,\nO LANCE ESTÁ SALVO.'), findsOneWidget);
    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();
    expect(find.text('TRÊS PASSOS.\nZERO TOQUES.'), findsOneWidget);
    expect(find.text('Apoie o celular'), findsOneWidget);
  });
}
