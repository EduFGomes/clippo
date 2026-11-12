import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/clippo_confirm_dialog.dart';
import 'package:clippo/core/widgets/clippo_message.dart';

/// Aviso curto no rodapé ("Lance salvo na galeria."). Ver [showClippoMessage], o mesmo de
/// todas as telas.
void showHomeMessage(BuildContext context, String message) => showClippoMessage(context, message);

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
