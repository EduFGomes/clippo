import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
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
    await tester.enterText(fields.at(1), 'Abc12345');
    await tester.enterText(fields.at(2), 'Abc12345');
    await tester.pump();
    await tester.tap(find.text('Criar conta').last);
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(fields.at(0), 'capovill@gmail.com');
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsNothing); // some ao corrigir
  });

  testWidgets('Criar conta confere o e-mail ao sair do campo, sem esperar o envio', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const SignUpScreen()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'capovill@g');
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsNothing); // digitando, sem bronca

    await tester.tap(fields.at(1));
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsOneWidget);
  });

  testWidgets('Complete seu perfil avisa ao sair do campo que o @ já é de alguém', (tester) async {
    await _phone(tester);
    final asked = <String>[];
    await tester.pumpWidget(_app(CompleteProfileScreen(
      usernameTaken: (username) async {
        asked.add(username);
        return username == 'rafa';
      },
    )));
    final fields = find.byType(TextField);

    await tester.enterText(fields.at(1), '@Rafa');
    await tester.tap(fields.at(2));
    await tester.pumpAndSettle();
    expect(asked, ['rafa']);
    expect(find.text(usernameTakenMessage), findsOneWidget);

    // Formato errado nem chega a perguntar.
    await tester.enterText(fields.at(1), 'ra..fa');
    await tester.tap(fields.at(0));
    await tester.pumpAndSettle();
    expect(asked, ['rafa']);
    expect(find.text('O ponto não pode ficar no começo, no fim ou repetido.'), findsOneWidget);

    await tester.enterText(fields.at(1), 'rafa.costa');
    await tester.tap(fields.at(2));
    await tester.pumpAndSettle();
    expect(asked, ['rafa', 'rafa.costa']);
    expect(find.text(usernameTakenMessage), findsNothing);
  });

  testWidgets('a data de nascimento explica como os dados são cuidados', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const CompleteProfileScreen()));
    await tester.ensureVisible(find.text('Como cuidamos dos seus dados'));
    await tester.tap(find.text('Como cuidamos dos seus dados'));
    await tester.pumpAndSettle();
    expect(find.text('Seus dados no Clippo'), findsOneWidget);
    expect(find.textContaining('Excluir conta'), findsOneWidget);
    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.text('Seus dados no Clippo'), findsNothing);
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

  testWidgets('"Esqueci a senha" pede um e-mail válido antes de enviar', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const SignInScreen()));
    await tester.tap(find.text('Esqueci a senha'));
    await tester.pump();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe a senha.'), findsNothing); // só o e-mail importa aqui

    await tester.enterText(find.byType(TextField).first, 'capovill@g');
    await tester.tap(find.text('Esqueci a senha'));
    await tester.pump();
    expect(find.text('Esse e-mail não parece válido.'), findsOneWidget);
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

  testWidgets('data de nascimento é digitada: a máscara põe as barras e a data é conferida', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const CompleteProfileScreen()));
    final birth = find.byType(TextField).at(2);

    await tester.enterText(birth, '1203');
    await tester.pump();
    expect(find.text('12/03'), findsOneWidget);

    // Colar com ou sem barras dá o mesmo; letras e números a mais ficam de fora.
    await tester.enterText(birth, '31/02/2001x9');
    await tester.pump();
    expect(find.text('31/02/2001'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pump();
    expect(find.text('Data de nascimento inválida.'), findsOneWidget);

    await tester.enterText(birth, '28022001');
    await tester.pump();
    expect(find.text('28/02/2001'), findsOneWidget);
    expect(find.text('Data de nascimento inválida.'), findsNothing); // some ao corrigir
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Criar conta" só habilita com senha forte (8+, maiúscula, minúscula, número) e confirmação igual',
      (tester) async {
    await tester.pumpWidget(_app(const SignUpScreen()));
    bool enabled() => tester
        .widget<ClippoPrimaryButton>(find.widgetWithText(ClippoPrimaryButton, 'Criar conta'))
        .enabled;

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'voce@email.com');
    await tester.enterText(fields.at(1), 'Abc1234');
    await tester.enterText(fields.at(2), 'Abc1234');
    await tester.pump();
    expect(enabled(), isFalse); // só 7 caracteres
    expect(find.text('8+ caracteres'), findsOneWidget);

    await tester.enterText(fields.at(1), 'abcd1234');
    await tester.enterText(fields.at(2), 'abcd1234');
    await tester.pump();
    expect(enabled(), isFalse); // sem maiúscula
    expect(find.text('falta maiúscula'), findsOneWidget);

    await tester.enterText(fields.at(1), 'Abcd1234');
    await tester.enterText(fields.at(2), 'Abcd1235');
    await tester.pump();
    expect(enabled(), isFalse); // não bate
    expect(find.text('Não bate'), findsOneWidget);
    expect(find.text('Pronto'), findsOneWidget);

    await tester.enterText(fields.at(2), 'Abcd1234');
    await tester.pump();
    expect(enabled(), isTrue);
    expect(find.bySemanticsLabel('A senha confere'), findsOneWidget);
  });
}
