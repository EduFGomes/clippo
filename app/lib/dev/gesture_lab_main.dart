import 'package:flutter/material.dart';

import 'package:clippo/app.dart';
import 'package:clippo/dev/gesture_lab_screen.dart';

/// Abre o laboratório do gesto direto, sem login e sem Firebase:
///   flutter run --flavor lab -t lib/dev/gesture_lab_main.dart
/// A detecção roda toda no celular (R8), então não precisa do Emulator.
void main() => runApp(const ClippoApp(home: GestureLabScreen()));
