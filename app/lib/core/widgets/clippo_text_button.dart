import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Ação secundária abaixo do botão primário, só texto (ex.: "Já tenho conta", "Sair").
class ClippoTextButton extends StatelessWidget {
  const ClippoTextButton({super.key, required this.label, required this.onPressed}) : onWine = false;

  /// Variante da boas-vindas, sobre o fundo vinho.
  const ClippoTextButton.onWine({super.key, required this.label, required this.onPressed}) : onWine = true;

  final String label;
  final VoidCallback? onPressed;
  final bool onWine;

  @override
  Widget build(BuildContext context) {
    final base = onWine ? ClippoBrand.onWine : ClippoColors.of(context).text;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: ClippoSize.textButtonHeight),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: ClippoText.link.copyWith(color: base.withValues(alpha: ClippoOpacity.textButton)),
          ),
        ),
      ),
    );
  }
}
