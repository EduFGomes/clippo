import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_confirm_dialog.dart';

/// Aviso curto no rodapé ("Lance salvo na galeria."), no mesmo vinho usado nas
/// outras telas do app.
void showHomeMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: ClippoBrand.wine,
        content: Text(
          message,
          style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
        ),
        duration: ClippoMotion.savedBanner,
      ),
    );
}

/// Pergunta antes de uma ação que não dá para desfazer sozinho. Ver [showClippoConfirm].
Future<bool> confirmHomeAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) =>
    showClippoConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    );
