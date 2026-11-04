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

/// As durações de highlight que o usuário pode escolher (R1). O Kotlin guarda no buffer o
/// suficiente para a maior (MAX_CLIP_SECONDS em ClippoCameraSession.kt): mudou aqui, mude lá.
abstract final class HighlightLength {
  static const List<Duration> options = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 45),
    Duration(seconds: 60),
  ];

  /// O padrão, quando o usuário não escolheu outra.
  static const Duration standard = Duration(seconds: 30);
}

/// O trecho que o buffer salvou: o MP4 no aparelho, ainda não enviado (R13 cuida do envio).
class SavedClip {
  const SavedClip({required this.path, required this.duration, this.withSound = false});

  factory SavedClip.fromMap(Map<Object?, Object?> data) => SavedClip(
        path: data['path'] as String,
        duration: Duration(milliseconds: data['durationMs'] as int),
        withSound: data['withSound'] as bool? ?? false,
      );

  /// Caminho do arquivo MP4 no aparelho.
  final String path;

  /// Quanto o trecho tem de fato: a duração escolhida, menos se a sessão começou há pouco (R5).
  final Duration duration;

  /// Se o MP4 tem som. Não tem quando o microfone não foi liberado ou não abriu.
  final bool withSound;
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

  /// Abre a pergunta de permissão do Android para a câmera e, junto, o microfone. Devolve se o
  /// usuário deixou a câmera (o microfone é opcional: veja [hasMicrophonePermission]).
  Future<bool> requestPermission() => _call<bool>('requestPermission').then((granted) => granted ?? false);

  /// O microfone é opcional: sem ele, o highlight sai só com imagem.
  Future<bool> hasMicrophonePermission() =>
      _call<bool>('hasMicrophonePermission').then((granted) => granted ?? false);

  /// Pede só o microfone. Vale na próxima vez que a câmera ligar ([start]).
  Future<bool> requestMicrophonePermission() =>
      _call<bool>('requestMicrophonePermission').then((granted) => granted ?? false);

  /// Liga a câmera traseira e a análise. [accurate] escolhe o modelo mais preciso do ML Kit
  /// (🟡 os dois existem até a medição a 8 m decidir). [multiPerson] acha cada pessoa do quadro
  /// com um detector antes do ML Kit (o modo escolhido); sem ele, o ML Kit segue uma pessoa só.
  ///
  /// Devolve se o buffer está gravando o som (o microfone liberado e aberto).
  Future<bool> start({bool accurate = false, bool multiPerson = false}) async {
    final data = await _call<Map<Object?, Object?>>('start', {'accurate': accurate, 'multiPerson': multiPerson});
    return data?['withSound'] as bool? ?? false;
  }

  Future<void> stop() => _call<void>('stop');

  /// Pede ao buffer para salvar o trecho de [length] (uma das [HighlightLength.options]) que
  /// termina em [until] (R1): a hora do quadro em que o gesto disparou ([PoseFrame.timestamp]),
  /// no relógio do sensor. O MP4 fica na pasta interna do app. Contrato em
  /// android/.../camera/README.md.
  Future<SavedClip> saveHighlight({required Duration until, Duration length = HighlightLength.standard}) async {
    if (!HighlightLength.options.contains(length)) {
      throw ArgumentError.value(length, 'length', 'Use uma de HighlightLength.options');
    }
    final data = await _call<Map<Object?, Object?>>(
      'saveHighlight',
      {'untilMicros': until.inMicroseconds, 'seconds': length.inSeconds},
    );
    if (data == null) throw const CameraFailure('O buffer não devolveu o trecho salvo.');
    return SavedClip.fromMap(data);
  }

  /// Avisa quem joga longe do celular que o highlight foi salvo: um bip ([sound]), um flash
  /// curto da lanterna ([flash]) e uma vibração leve ([vibration]). Chame depois de
  /// [saveHighlight], para não atrasar o salvamento (R2).
  Future<void> signalSaved({bool sound = true, bool flash = true, bool vibration = false}) =>
      _call<void>('signalSaved', {'sound': sound, 'flash': flash, 'vibrate': vibration});

  /// SÓ PARA A FASE DE TESTES: copia o MP4 de um [SavedClip] para a galeria (álbum Clippo), para
  /// o time assistir no celular. O produto guarda o highlight só na pasta do app.
  Future<void> copyToGallery(SavedClip clip) => _call<String>('copyToGallery', {'path': clip.path});

  /// Apaga da pasta interna do app o MP4 de um [SavedClip] (quando o usuário descarta a sessão,
  /// R14, ou depois que o envio para o banco é confirmado, R13).
  Future<void> deleteHighlight(SavedClip clip) => _call<void>('deleteHighlight', {'path': clip.path});

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
        'detector-failed' => const CameraFailure('Não foi possível abrir o detector de pessoas.'),
        'analysis-failed' => const CameraFailure('Não foi possível analisar a imagem da câmera.'),
        'encoder-init-failed' => const CameraFailure('Não foi possível ligar a gravação dos lances.'),
        'buffer-failed' => const CameraFailure('A gravação dos lances parou. Feche e abra a câmera de novo.'),
        'save-failed' => const CameraFailure('Não foi possível salvar o lance.'),
        'gallery-unavailable' => const CameraFailure('A galeria só funciona no Android 10 ou mais novo.'),
        'gallery-failed' => const CameraFailure('Não foi possível copiar o lance para a galeria.'),
        'delete-failed' => const CameraFailure('Não foi possível apagar o lance.'),
        _ => CameraFailure('Algo deu errado com a câmera (${e.code}).'),
      };
}
