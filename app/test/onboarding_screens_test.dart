import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/features/onboarding/screens/complete_profile_screen.dart';
import 'package:clippo/features/onboarding/screens/how_it_works_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';
import 'package:clippo/features/onboarding/screens/welcome_screen.dart';

// As telas abrem sem Firebase: o AuthRepository só é usado ao enviar.
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
  final screens = <String, Widget>{
    'Boas-vindas': const WelcomeScreen(),
    'Como funciona': const HowItWorksScreen(enterFromWelcome: true),
    'Criar conta': const SignUpScreen(),
    'Entrar': const SignInScreen(),
    'Complete seu perfil': const CompleteProfileScreen(),
  };

  for (final MapEntry(key: name, value: screen) in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('$name abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
          tester.view.physicalSize = const Size(412, 915);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(_app(screen, brightness: brightness, textScale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('textos das telas seguem o design', (tester) async {
    await tester.pumpWidget(_app(const SignUpScreen()));
    expect(find.text('CRIAR\nCONTA.'), findsOneWidget);
    expect(find.text('Seus lances ficam guardados na sua conta.'), findsOneWidget);

    await tester.pumpWidget(_app(const SignInScreen()));
    expect(find.text('DE VOLTA\nAO JOGO.'), findsOneWidget);
    expect(find.text('Esqueci a senha'), findsOneWidget);

    await tester.pumpWidget(_app(const CompleteProfileScreen()));
    expect(find.text('QUASE\nLÁ.'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  // Nestes testes não existe Firebase: se a tela tentasse enviar algo, o teste quebraria.
  testWidgets('Criar conta recusa e-mail inválido sem chamar o Firebase', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const SignUpScreen()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'capovill@g');
    await tester.enterText(fields.at(1), 'abc123');
    await tester.enterText(fields.at(2), 'abc123');
    await tester.pump();
    await tester.tap(find.text('Criar conta').last);
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(fields.at(0), 'capovill@gmail.com');
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsNothing); // some ao corrigir
  });

  testWidgets('Entrar pede e-mail e senha antes de enviar', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const SignInScreen()));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Complete seu perfil confere os três campos antes de enviar', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const CompleteProfileScreen()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'ra..fa');
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsOneWidget);
    expect(find.text('O ponto não pode ficar no começo, no fim ou repetido.'), findsOneWidget);
    expect(find.text('Informe a data de nascimento.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Criar conta" só habilita com senha de 6+ e confirmação igual', (tester) async {
    await tester.pumpWidget(_app(const SignUpScreen()));
    bool enabled() => tester
        .widget<ClippoPrimaryButton>(find.widgetWithText(ClippoPrimaryButton, 'Criar conta'))
        .enabled;

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'voce@email.com');
    await tester.enterText(fields.at(1), 'abc12');
    await tester.enterText(fields.at(2), 'abc12');
    await tester.pump();
    expect(enabled(), isFalse); // só 5 caracteres
    expect(find.text('6+ caracteres'), findsOneWidget);

    await tester.enterText(fields.at(1), 'abc123');
    await tester.enterText(fields.at(2), 'abc124');
    await tester.pump();
    expect(enabled(), isFalse); // não bate
    expect(find.text('Não bate'), findsOneWidget);
    expect(find.text('Pronto'), findsOneWidget);

    await tester.enterText(fields.at(2), 'abc123');
    await tester.pump();
    expect(enabled(), isTrue);
    expect(find.bySemanticsLabel('A senha confere'), findsOneWidget);
  });
}
