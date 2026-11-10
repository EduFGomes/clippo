import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/user_profile.dart';
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

const _laura = UserProfile(
  uid: 'laura',
  name: 'Laura Suzuki',
  username: 'lasuzukii',
  sessionCount: 5,
  highlightCount: 21,
  friendCount: 3,
);

/// Faz o papel do Firestore + updateProfile: guarda o que foi pedido e emite o perfil novo.
class _FakeBackend {
  final controller = StreamController<UserProfile?>();
  final calls = <Map<String, String?>>[];
  UserProfile current = _laura;

  /// Quando preenchido, o próximo salvar falha com este erro (como o servidor responderia).
  AuthFailure? failNext;

  void emit(UserProfile? p) => controller.add(p);

  Future<void> save({String? name, String? username}) async {
    calls.add({'name': name, 'username': username});
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
    current = UserProfile(
      uid: current.uid,
      name: name?.trim() ?? current.name,
      username: username?.trim().toLowerCase() ?? current.username,
      sessionCount: current.sessionCount,
      highlightCount: current.highlightCount,
      friendCount: current.friendCount,
    );
    controller.add(current);
  }
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

  testWidgets('mostra nome, @ e as estatísticas que vêm do perfil', (tester) async {
    var signedOut = false;
    final backend = _FakeBackend();
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(
      profile: backend.controller.stream,
      saveProfile: backend.save,
      onSignOut: () => signedOut = true,
    )));

    // Carregando: ainda sem dados.
    expect(find.bySemanticsLabel('Carregando seu perfil'), findsOneWidget);
    expect(find.text('Laura Suzuki'), findsNothing);

    backend.emit(_laura);
    await tester.pump();

    expect(find.text('SEU\nPERFIL.'), findsOneWidget);
    expect(find.text('Editar foto'), findsOneWidget);
    expect(find.text('Laura Suzuki'), findsNWidgets(2)); // cabeçalho + linha Nome
    expect(find.text('@lasuzukii'), findsNWidgets(2));
    expect(find.text('sessões'), findsOneWidget);
    expect(find.text('highlights'), findsOneWidget);
    expect(find.text('amigos'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Notificações'), findsOneWidget);

    // Em tempo real: o contador muda sem reabrir a tela.
    backend.emit(const UserProfile(
      uid: 'laura',
      name: 'Laura Suzuki',
      username: 'lasuzukii',
      sessionCount: 6,
      highlightCount: 21,
      friendCount: 3,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('5'), findsNothing);
    expect(find.text('6'), findsOneWidget);

    await tester.tap(find.text('Sair da conta'));
    await tester.pump();
    expect(signedOut, isTrue);
  });

  testWidgets('erro ao carregar mostra a mensagem e o botão de tentar de novo', (tester) async {
    final backend = _FakeBackend();
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(profile: backend.controller.stream)));
    backend.controller.addError(Exception('sem rede'));
    await tester.pump();

    expect(
      find.text('Não deu para carregar seu perfil. Confira a internet e tente de novo.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    backend.emit(_laura);
    await tester.pumpAndSettle();
    expect(find.text('Laura Suzuki'), findsNWidgets(2));
  });

  testWidgets('perfil que não existe avisa', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(profile: Stream<UserProfile?>.value(null))));
    await tester.pump();
    expect(find.text('Não achamos seu perfil.'), findsOneWidget);
  });

  testWidgets('alterna notificações ao tocar na linha', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await tester.pump();

    bool isEnabled() => tester.widget<ProfileToggleTile>(find.byType(ProfileToggleTile)).value;
    expect(isEnabled(), isTrue);

    await tester.tap(find.text('Notificações'));
    await tester.pumpAndSettle();
    expect(isEnabled(), isFalse);
  });

  testWidgets('editar o nome valida antes de enviar e envia só o nome', (tester) async {
    final backend = _FakeBackend();
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(
      profile: backend.controller.stream,
      saveProfile: backend.save,
    )));
    backend.emit(_laura);
    await tester.pump();

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    expect(find.text('SEU\nNOME.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsOneWidget);
    expect(backend.calls, isEmpty); // não chamou o servidor

    await tester.enterText(find.byType(TextField), 'Laura S. Suzuki');
    await tester.pump();
    expect(find.text('Informe seu nome.'), findsNothing);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(backend.calls, [
      {'name': 'Laura S. Suzuki', 'username': null},
    ]);
    expect(find.text('SEU\nNOME.'), findsNothing); // voltou ao Perfil
    expect(find.text('Laura S. Suzuki'), findsNWidgets(2));
  });

  testWidgets('editar o @ mostra embaixo do campo o erro do servidor', (tester) async {
    final backend = _FakeBackend();
    await _phone(tester);
    await tester.pumpWidget(_app(ProfileScreen(
      profile: backend.controller.stream,
      saveProfile: backend.save,
    )));
    backend.emit(_laura);
    await tester.pump();

    await tester.tap(find.text('Usuário'));
    await tester.pumpAndSettle();
    expect(find.text('SEU\nUSUÁRIO.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'laura..suzuki');
    await tester.tap(find.text('Salvar'));
    await tester.pump();
    expect(find.text('O ponto não pode ficar no começo, no fim ou repetido.'), findsOneWidget);
    expect(backend.calls, isEmpty);

    backend.failNext = const AuthFailure('Esse nome de usuário já está em uso.', field: 'username');
    await tester.enterText(find.byType(TextField), 'gustavo.rocha');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Esse nome de usuário já está em uso.'), findsOneWidget);
    expect(find.text('SEU\nUSUÁRIO.'), findsOneWidget); // continua na edição

    await tester.enterText(find.byType(TextField), 'laura.suzuki');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(backend.calls.last, {'name': null, 'username': 'laura.suzuki'});
    expect(find.text('@laura.suzuki'), findsNWidgets(2)); // cabeçalho + linha Usuário
  });

  testWidgets('sem login (catálogo), edita o exemplo na memória', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(const ProfileScreen()));
    await tester.pump();
    expect(find.text('Gustavo Rocha'), findsNWidgets(2));
    expect(find.text('12'), findsOneWidget);

    await tester.tap(find.text('Nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Laura   Suzuki ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Laura Suzuki'), findsNWidgets(2));
  });
}
