import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';

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

/// Pergunta antes de uma ação que não dá para desfazer sozinho (sair da sessão).
/// Mesmo desenho da confirmação da Gravação: ação principal em cima, saída embaixo.
Future<bool> confirmHomeAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
}) async {
  final confirmed = await showDialog<bool>(
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
              ClippoPrimaryButton(
                label: confirmLabel,
                onPressed: () => Navigator.of(dialogContext).pop(true),
              ),
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
