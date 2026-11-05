import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/app.dart';
import 'package:clippo/dev/gesture_lab_screen.dart';

/// Abre o laboratório do gesto direto, sem login e sem Firebase:
///   flutter run --flavor lab -t lib/dev/gesture_lab_main.dart
/// A detecção roda toda no celular (R8), então não precisa do Emulator.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A tela fica sempre em pé, mesmo com o celular deitado no tripé: a análise e o esqueleto
  // desenhado por cima assumem isso, e a posição do celular vem do acelerômetro
  // (ClippoCameraSession). Girando a tela, o esqueleto sairia do lugar.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const ClippoApp(home: GestureLabScreen()));
}
