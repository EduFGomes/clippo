import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';

/// Pergunta antes de uma ação que não dá para desfazer sozinho (sair da sessão, excluir).
/// Ação principal em cima, saída segura embaixo. Devolve true só se a pessoa confirmou.
///
/// [destructive]: a ação apaga algo (excluir, remover) e ganha o botão em `error`.
Future<bool> showClippoConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final colors = ClippoColors.of(dialogContext);
      void confirm() => Navigator.of(dialogContext).pop(true);
      return Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClippoSpace.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.spaceS),
              Text(message, style: ClippoText.body.copyWith(color: colors.textMuted)),
              const SizedBox(height: ClippoSpace.spaceL),
              if (destructive)
                ClippoPrimaryButton.danger(label: confirmLabel, onPressed: confirm)
              else
                ClippoPrimaryButton(label: confirmLabel, onPressed: confirm),
              const SizedBox(height: ClippoSpace.spaceS),
              ClippoTextButton(
                label: cancelLabel,
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}

/// Explica algo sem pedir decisão ("Como cuidamos dos seus dados"): o mesmo diálogo do
/// [showClippoConfirm], com um botão só para fechar.
Future<void> showClippoNotice(
  BuildContext context, {
  required String title,
  required String message,
  String closeLabel = 'Entendi',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final colors = ClippoColors.of(dialogContext);
      return Dialog(
        backgroundColor: colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(ClippoSpace.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.spaceS),
              Text(message, style: ClippoText.body.copyWith(color: colors.textMuted)),
              const SizedBox(height: ClippoSpace.spaceL),
              ClippoPrimaryButton(label: closeLabel, onPressed: () => Navigator.of(dialogContext).pop()),
            ],
          ),
        ),
      );
    },
  );
}
