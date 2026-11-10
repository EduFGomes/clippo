import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Pílula contornada sobre o preto da Gravação, para a ação que desfaz ("Cancelar gravação").
class ClippoGhostButton extends StatelessWidget {
  const ClippoGhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: ClippoSize.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL, vertical: ClippoSpace.spaceM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
            border: Border.all(color: ClippoBrand.captureGhostBorder, width: ClippoSize.border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: ClippoText.button.copyWith(color: ClippoBrand.onWine.withValues(alpha: ClippoOpacity.textButton)),
          ),
        ),
      ),
    );
  }
}
