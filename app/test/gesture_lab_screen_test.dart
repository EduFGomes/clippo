import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/app.dart';
import 'package:clippo/dev/gesture_lab_screen.dart';

// Só os estados sem imagem: a câmera ligada usa uma platform view (AndroidView), que não existe
// no teste. Esse estado é testado no celular.
const _commands = MethodChannel('clippo/camera');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(_commands, null));

  /// Um Kotlin de mentira: sem permissão, e [allow] decide a resposta do pedido.
  void fakeCamera({required bool allow}) {
    messenger.setMockMethodCallHandler(_commands, (call) async {
      return switch (call.method) {
        'hasPermission' => false,
        'requestPermission' => allow,
        _ => null,
      };
    });
  }

  testWidgets('sem permissão, pede a câmera', (tester) async {
    fakeCamera(allow: false);
    await tester.pumpWidget(const ClippoApp(home: GestureLabScreen()));
    await tester.pumpAndSettle();
    expect(find.text('A detecção do gesto precisa da câmera.'), findsOneWidget);
    expect(find.text('Permitir câmera'), findsOneWidget);
  });

  testWidgets('permissão recusada explica onde liberar', (tester) async {
    fakeCamera(allow: false);
    await tester.pumpWidget(const ClippoApp(home: GestureLabScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir câmera'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Configurações › Apps › Clippo'), findsOneWidget);
  });

  testWidgets('erro da câmera aparece com "Tentar de novo"', (tester) async {
    messenger.setMockMethodCallHandler(_commands, (call) async {
      if (call.method == 'hasPermission') return true;
      throw PlatformException(code: 'camera-unavailable');
    });
    await tester.pumpWidget(const ClippoApp(home: GestureLabScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível abrir a câmera'), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
