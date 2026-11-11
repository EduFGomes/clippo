import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// O aviso do app depois de uma ação ("Pedido enviado.", "Lance apagado.", um erro do servidor):
/// faixa vinho no rodapé, some sozinha em `savedBanner`. Um aviso novo troca o anterior.
///
/// É o único jeito de avisar o resultado de uma ação fora da Gravação (docs/design.md ›
/// Avisos). Erro de formulário fica embaixo do campo; a Gravação usa o `ClippoCaptureToast`.
void showClippoMessage(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: ClippoBrand.wine,
        content: Semantics(
          liveRegion: true,
          child: Text(message, style: ClippoText.label.copyWith(color: ClippoBrand.onWine)),
        ),
        duration: ClippoMotion.savedBanner,
      ),
    );
}
