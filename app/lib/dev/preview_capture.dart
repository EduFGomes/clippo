import 'dart:async';

import 'package:flutter/material.dart';

import 'package:clippo/app.dart';
import 'package:clippo/core/camera/clippo_camera.dart';
import 'package:clippo/core/camera/pose_frame.dart';
import 'package:clippo/core/gesture/gesture_pipeline.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';

/// Abre só a Gravação, sem login e com a câmera SIMULADA: flutter run -t lib/dev/preview_capture.dart
///
/// Serve para ver a tela no emulador do Android Studio, cujas câmeras não aceitam os 3 fluxos
/// da câmera de verdade (imagem, análise e buffer). Para testar a câmera, use um celular e o
/// catálogo do app (Gravar) ou o laboratório do gesto.
void main() {
  runApp(
    ClippoApp(
      home: CaptureScreen(
        camera: _SimulatedCamera(),
        pipeline: _SimulatedGesture(),
        preview: (_) => const ColoredBox(color: ClippoBrand.wineDeep),
        friends: const [
          CaptureFriend(id: 'rafa', firstName: 'Rafa'),
          CaptureFriend(id: 'bruno', firstName: 'Bruno'),
          CaptureFriend(id: 'alice', firstName: 'Alice'),
        ],
      ),
    ),
  );
}

/// Câmera de mentira: sempre com permissão, e "salva" na hora.
class _SimulatedCamera extends ClippoCamera {
  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start({bool accurate = false, bool multiPerson = false}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<SavedClip> saveHighlight({required Duration until}) async =>
      const SavedClip(path: 'simulado.mp4', duration: Duration(seconds: 30));

  @override
  Stream<PoseFrame> get poses => const Stream.empty();
}

/// Detecção de mentira: um quadro por segundo, e o gesto dispara a cada 3 s.
class _SimulatedGesture extends GesturePipeline {
  @override
  Stream<GestureObservation> watch(Stream<PoseFrame> frames) {
    return Stream.periodic(const Duration(seconds: 1), (second) {
      return GestureObservation(
        frame: PoseFrame(
          timestamp: Duration(seconds: second),
          width: 720,
          height: 1280,
          analysisTime: Duration.zero,
        ),
        people: const [],
        triggered: second > 0 && second % 3 == 0,
      );
    });
  }
}
