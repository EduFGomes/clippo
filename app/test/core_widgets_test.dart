import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_highlight_tile.dart';
import 'package:clippo/core/widgets/clippo_password_meter.dart';
import 'package:clippo/core/widgets/clippo_pill_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/dev/component_gallery.dart';

Widget _app(Widget home, {Brightness brightness = Brightness.light, double textScale = 1}) {
  return MaterialApp(
    theme: clippoTheme(brightness),
    home: MediaQuery(
      data: MediaQueryData(size: const Size(412, 915), textScaler: TextScaler.linear(textScale)),
      child: home,
    ),
  );
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('galeria abre sem cortar ($brightness, fonte ${scale * 100}%)', (tester) async {
        await _setPhoneSize(tester);
        await tester.pumpWidget(_app(const ComponentGallery(), brightness: brightness, textScale: scale));
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        expect(find.text('GALERIA DE\nCOMPONENTES.'), findsOneWidget);
      });
    }
  }

  testWidgets('título fica em maiúsculas e o subtítulo aparece', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(
      body: ClippoScreenTitle(line1: 'Criar', line2: 'conta.', subtitle: 'Seus lances ficam guardados na sua conta.'),
    )));
    expect(find.text('CRIAR\nCONTA.'), findsOneWidget);
    expect(find.text('Seus lances ficam guardados na sua conta.'), findsOneWidget);
  });

  testWidgets('botão destrutivo usa a cor de erro do tema e responde ao toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: ClippoPrimaryButton.danger(label: 'Excluir', onPressed: () => taps++),
    )));
    final box = tester.widget<Container>(
      find.descendant(of: find.byType(ClippoPrimaryButton), matching: find.byType(Container)).first,
    );
    expect((box.decoration as BoxDecoration).color, ClippoColors.light.error);
    await tester.tap(find.text('Excluir'));
    expect(taps, 1);
  });

  testWidgets('pílula tem 48 dp de toque, rótulo próprio e avisa ao tocar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: Center(
        child: ClippoPillButton(label: 'Gravar', icon: 'capture', semanticLabel: 'Gravar uma sessão', onPressed: () => taps++),
      ),
    )));
    expect(tester.getSize(find.byType(ClippoPillButton)).height, greaterThanOrEqualTo(ClippoSize.minTouchTarget));
    await tester.tap(find.bySemanticsLabel('Gravar uma sessão'));
    expect(taps, 1);
  });

  testWidgets('botão primário desabilitado não responde', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: Column(children: [
        ClippoPrimaryButton(label: 'Desligado', onPressed: () => taps++, enabled: false),
        ClippoPrimaryButton(label: 'Ligado', onPressed: () => taps++),
      ]),
    )));
    await tester.tap(find.text('Desligado'));
    expect(taps, 0);
    await tester.tap(find.text('Ligado'));
    expect(taps, 1);
  });

  testWidgets('medidor diz o que falta até a senha ficar forte', (tester) async {
    for (final (password, caption) in [
      ('Abc123', '8+ caracteres'),
      ('abcd1234', 'falta maiúscula'),
      ('ABCD1234', 'falta minúscula'),
      ('Abcdefgh', 'falta número'),
      ('Abcd1234', 'Pronto'),
    ]) {
      await tester.pumpWidget(_app(Scaffold(body: ClippoPasswordMeter(password: password))));
      expect(find.text(caption), findsOneWidget, reason: password);
    }
  });

  testWidgets('olho alterna mostrar e ocultar senha', (tester) async {
    final controller = TextEditingController(text: 'segredo');
    addTearDown(controller.dispose);
    await tester.pumpWidget(_app(Scaffold(body: ClippoTextField.password(label: 'Senha', controller: controller))));
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.bySemanticsLabel('Mostrar senha'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.bySemanticsLabel('Ocultar senha'), findsOneWidget);
  });

  testWidgets('confirmação mostra ✓ quando bate e "Não bate" quando não', (tester) async {
    final password = TextEditingController(text: 'abcdef');
    final confirm = TextEditingController();
    addTearDown(password.dispose);
    addTearDown(confirm.dispose);
    await tester.pumpWidget(_app(Scaffold(
      body: ClippoTextField.confirmation(label: 'Confirme a senha', controller: confirm, password: password),
    )));
    confirm.text = 'abc';
    await tester.pump();
    expect(find.text('Não bate'), findsNothing); // ainda digitando
    confirm.text = 'abcdeX';
    await tester.pump();
    expect(find.text('Não bate'), findsOneWidget);
    confirm.text = 'abcdef';
    await tester.pump();
    expect(find.text('Não bate'), findsNothing);
    expect(find.bySemanticsLabel('A senha confere'), findsOneWidget);
  });

  testWidgets('entrada vinda da boas-vindas desfaz o vinho e libera o toque', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(ClippoScreenGround(
      enterFromWelcome: true,
      child: ClippoPrimaryButton(label: 'Seguir', onPressed: () => taps++),
    )));
    await tester.tap(find.text('Seguir')); // a camada vinho não bloqueia toques
    expect(taps, 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('fileira de avatares mostra os primeiros e o "+N"', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(_app(const Center(
      child: ClippoAvatarRow(
        people: [
          ClippoAvatarPerson(name: 'Alice Prado'),
          ClippoAvatarPerson(name: 'Bruno'),
        ],
        hidden: 8,
      ),
    )));

    // Sem foto, cada avatar mostra a inicial do nome.
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('+8'), findsOneWidget);
  });

  testWidgets('sem ninguém de fora, a fileira não mostra "+0"', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(_app(const Center(
      child: ClippoAvatarRow(people: [ClippoAvatarPerson(name: 'Alice')]),
    )));

    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('card de sessão fechado esconde local, participantes e ação', (tester) async {
    await _setPhoneSize(tester);
    await tester.pumpWidget(_app(ClippoSessionCard(
      title: 'Pelada de quinta',
      summary: '11 set 2026 · 7 highlights',
      location: 'Quadra do Parque',
      details: '1h 42min · 10 participantes',
      expanded: false,
      onToggle: () {},
      onAction: () {},
    )));

    expect(find.text('Pelada de quinta'), findsOneWidget);
    expect(find.text('11 set 2026 · 7 highlights'), findsOneWidget);
    expect(find.text('Quadra do Parque'), findsNothing);
    expect(find.text('Ver highlights'), findsNothing);
  });

  testWidgets('card aberto mostra tudo e o toque avisa a tela', (tester) async {
    await _setPhoneSize(tester);
    var toggles = 0;
    var actions = 0;
    await tester.pumpWidget(_app(ClippoSessionCard(
      title: 'Pelada de quinta',
      summary: '11 set 2026 · 7 highlights',
      location: 'Quadra do Parque',
      details: '1h 42min · 10 participantes',
      expanded: true,
      onToggle: () => toggles++,
      onAction: () => actions++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Quadra do Parque'), findsOneWidget);
    expect(find.text('1h 42min · 10 participantes'), findsOneWidget);

    await tester.tap(find.text('Ver highlights'));
    await tester.pumpAndSettle();
    expect(actions, 1);

    // Com ação, tocar no card já faz a ação; o chevron é quem abre e fecha.
    await tester.tap(find.text('Pelada de quinta'));
    await tester.pumpAndSettle();
    expect(actions, 2);
    expect(toggles, 0);

    await tester.tap(find.bySemanticsLabel('Esconder detalhes de Pelada de quinta'));
    await tester.pumpAndSettle();
    expect(toggles, 1);
    expect(tester.getSize(find.bySemanticsLabel('Esconder detalhes de Pelada de quinta')),
        const Size.square(ClippoSize.minTouchTarget));
  });

  testWidgets('card sem ação abre e fecha pelo toque no card inteiro', (tester) async {
    await _setPhoneSize(tester);
    var toggles = 0;
    await tester.pumpWidget(_app(ClippoSessionCard(
      title: 'Pelada de quinta',
      summary: '11 set 2026 · 7 highlights',
      expanded: false,
      onToggle: () => toggles++,
    )));

    await tester.tap(find.text('Pelada de quinta'));
    await tester.pumpAndSettle();
    expect(toggles, 1);
    expect(find.bySemanticsLabel(RegExp('detalhes de')), findsNothing);
  });

  testWidgets('chip, pílula e voltar apagam enquanto o dedo está em cima', (tester) async {
    await _setPhoneSize(tester);
    var taps = 0;
    await tester.pumpWidget(_app(ClippoPillButton(label: 'Gravar', icon: 'capture', onPressed: () => taps++)));

    double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;
    expect(opacity(), 1);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Gravar')));
    await tester.pumpAndSettle();
    expect(opacity(), ClippoOpacity.pressed);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(opacity(), 1);
    expect(taps, 1);
  });

  testWidgets('linha de highlight mostra título, momento e avisa ao tocar', (tester) async {
    await _setPhoneSize(tester);
    var taps = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: ClippoHighlightTile(
        title: 'Lance 3',
        timing: '00:12:40 · 30s',
        onTap: () => taps++,
      ),
    )));

    expect(find.text('Lance 3'), findsOneWidget);
    expect(find.text('00:12:40 · 30s'), findsOneWidget);

    await tester.tap(find.text('Lance 3'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('linha de highlight mostra a miniatura quando recebe uma, e a quadra sem ela', (tester) async {
    await _setPhoneSize(tester);
    Widget tile(ImageProvider? thumbnail) => _app(Scaffold(
          body: ClippoHighlightTile(
            title: 'Lance 3',
            timing: '00:12:40 · 30s',
            thumbnail: thumbnail,
            onTap: () {},
          ),
        ));
    Finder inTile(Type type) =>
        find.descendant(of: find.byType(ClippoHighlightTile), matching: find.byType(type));

    await tester.pumpWidget(tile(null));
    expect(inTile(Image), findsNothing);

    final image = FileImage(File('/data/highlights/lance-3.jpg'));
    await tester.pumpWidget(tile(image));
    expect(tester.widget<Image>(inTile(Image)).image, image);
  });
}
