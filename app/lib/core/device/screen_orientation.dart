import 'package:flutter/services.dart';

/// Em que posições o app pode ficar.
///
/// O app fica sempre em pé. Só a Gravação gira com o celular, porque um lance pode ser
/// gravado deitado. O Player fica deitado apenas na tela cheia, que a pessoa liga por um
/// botão (docs/produto.md › 4.4). Quem libera uma posição devolve o app para em pé ao sair.
abstract final class ClippoOrientation {
  /// O normal do app: em pé.
  static Future<void> portrait() =>
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

  /// Gira com o celular (Gravação).
  static Future<void> free() => SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);

  /// Deitado para qualquer lado (tela cheia do Player com vídeo deitado).
  static Future<void> landscape() => SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
}
