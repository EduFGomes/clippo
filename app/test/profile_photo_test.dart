import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';

Widget _app(Widget home) => MaterialApp(theme: clippoTheme(Brightness.light), home: home);

const _semFoto = UserProfile(uid: 'laura', name: 'Laura Suzuki', username: 'lasuzukii');
const _comFoto = UserProfile(
  uid: 'laura',
  name: 'Laura Suzuki',
  username: 'lasuzukii',
  photoUrl: 'https://exemplo.test/foto.jpg',
);

/// Um arquivo de verdade no temporário (o app confere o tamanho antes de enviar).
Future<File> _arquivo(String nome, int bytes) async {
  final dir = await Directory.systemTemp.createTemp('clippo-foto');
  final file = File('${dir.path}/$nome');
  await file.writeAsBytes(List<int>.filled(bytes, 1));
  return file;
}

/// A IO de arquivo roda fora do relógio falso dos testes.
Future<void> _deixarRodar(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('sem foto: "Adicionar foto" escolhe da galeria e envia', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final file = (await tester.runAsync(() => _arquivo('foto.jpg', 2048)))!;
    final enviadas = <String>[];
    ImageSource? origem;

    await tester.pumpWidget(_app(ProfileScreen(
      profile: Stream.value(_semFoto),
      saveProfile: ({name, username}) async {},
      pickPhoto: (source) async {
        origem = source;
        return file;
      },
      savePhoto: (f) async => enviadas.add(f.path),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Foto do perfil'), findsOneWidget);
    expect(find.text('Remover foto'), findsNothing); // sem foto, nada para tirar
    await tester.tap(find.text('Escolher da galeria'));
    await _deixarRodar(tester);

    expect(origem, ImageSource.gallery);
    expect(enviadas, [file.path]);
    expect(find.text('Foto atualizada.'), findsOneWidget);
  });

  testWidgets('foto que não é JPEG nem PNG nem chega a ser enviada (regra 0)', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gif = (await tester.runAsync(() => _arquivo('foto.gif', 2048)))!;
    var enviou = false;

    await tester.pumpWidget(_app(ProfileScreen(
      profile: Stream.value(_semFoto),
      saveProfile: ({name, username}) async {},
      pickPhoto: (_) async => gif,
      savePhoto: (_) async => enviou = true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await _deixarRodar(tester);

    expect(enviou, isFalse);
    expect(find.text('Use uma foto em JPEG ou PNG.'), findsOneWidget);
  });

  testWidgets('com foto: "Trocar foto" oferece remover, que pergunta antes', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var removeu = 0;

    await tester.pumpWidget(_app(ProfileScreen(
      profile: Stream.value(_comFoto),
      saveProfile: ({name, username}) async {},
      pickPhoto: (_) async => null,
      savePhoto: (_) async {},
      removePhoto: () async => removeu++,
    )));
    // A foto vem da rede: nos testes ela não carrega, e as iniciais ficam.
    await tester.pump();

    await tester.tap(find.text('Trocar foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover foto'));
    await tester.pumpAndSettle();
    expect(find.text('Remover a foto?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Remover foto')));
    await tester.pumpAndSettle();
    expect(removeu, 1);
    expect(find.text('Foto removida.'), findsOneWidget);
  });

  testWidgets('sem login e sem quem envie (catálogo), o botão da foto não aparece', (tester) async {
    await tester.pumpWidget(_app(ProfileScreen(
      profile: Stream.value(_semFoto),
      saveProfile: ({name, username}) async {},
    )));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar foto'), findsNothing);
  });
}
