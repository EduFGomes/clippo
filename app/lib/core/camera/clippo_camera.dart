import 'dart:async';

import 'package:flutter/services.dart';

import 'package:clippo/core/camera/pose_frame.dart';

/// Erro da câmera com uma mensagem pronta para mostrar na tela.
class CameraFailure implements Exception {
  const CameraFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A câmera do app, do lado Dart: comandos e o fluxo de poses.
///
/// Quem abre a câmera de verdade é o código nativo (android/.../camera/ClippoCameraSession.kt).
/// Aqui só conversamos com ele pelos canais. Os nomes dos canais e dos métodos precisam bater
/// com os do Kotlin.
class ClippoCamera {
  const ClippoCamera();

  static const MethodChannel _commands = MethodChannel('clippo/camera');
  static const EventChannel _poses = EventChannel('clippo/camera/poses');

  /// Tipo da platform view que mostra a imagem da câmera (para um `AndroidView`).
  static const String previewViewType = 'clippo/camera-preview';

  Future<bool> hasPermission() => _call<bool>('hasPermission').then((granted) => granted ?? false);

  /// Abre a pergunta de permissão do Android. Devolve se o usuário deixou.
  Future<bool> requestPermission() => _call<bool>('requestPermission').then((granted) => granted ?? false);

  /// Liga a câmera traseira e a análise. [accurate] escolhe o modelo mais preciso do ML Kit
  /// (🟡 os dois existem até a medição a 8 m decidir).
  Future<void> start({bool accurate = false}) => _call<void>('start', {'accurate': accurate});

  Future<void> stop() => _call<void>('stop');

  /// Um [PoseFrame] por quadro analisado, enquanto a câmera estiver ligada.
  ///
  /// O nativo só começa a mandar quando alguém escuta, e para quando a escuta é cancelada.
  Stream<PoseFrame> get poses => _poses
      .receiveBroadcastStream()
      .map((event) => PoseFrame.fromMap(event as Map<Object?, Object?>))
      .transform(StreamTransformer.fromHandlers(handleError: (error, stack, sink) {
        sink.addError(error is PlatformException ? _translate(error) : error, stack);
      }));

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _commands.invokeMethod<T>(method, arguments);
    } on PlatformException catch (e) {
      throw _translate(e);
    }
  }

  /// Os códigos de erro vêm do Kotlin (result.error / poseSink.error).
  CameraFailure _translate(PlatformException e) => switch (e.code) {
        'no-permission' => const CameraFailure('O Clippo precisa da câmera para reconhecer o gesto.'),
        'camera-unavailable' => const CameraFailure('Não foi possível abrir a câmera. Feche outros apps que estejam usando e tente de novo.'),
        'permission-pending' => const CameraFailure('Responda o pedido de permissão que está aberto.'),
        'analysis-failed' => const CameraFailure('Não foi possível analisar a imagem da câmera.'),
        _ => CameraFailure('Algo deu errado com a câmera (${e.code}).'),
      };
}
