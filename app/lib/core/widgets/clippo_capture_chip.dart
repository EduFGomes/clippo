import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Chip de escolha sobre a câmera ("Gravar sozinho", "Com Rafa"). Só na Gravação.
class ClippoCaptureChip extends StatelessWidget {
  const ClippoCaptureChip({super.key, required this.label, required this.selected, required this.onPressed});

  final String label;

  /// Selecionado: pêssego com texto escuro. Senão: translúcido com borda.
  final bool selected;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus,
            curve: ClippoMotion.standard,
            constraints: const BoxConstraints(minHeight: ClippoSize.captureChip),
            padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL),
            decoration: BoxDecoration(
              color: selected ? ClippoBrand.peach : ClippoBrand.captureChip,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
              border: Border.all(
                color: selected ? ClippoBrand.peach : ClippoBrand.captureChipBorder,
                width: ClippoSize.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: ClippoText.label.copyWith(color: selected ? ClippoBrand.onPeach : ClippoBrand.onWine),
            ),
          ),
        ),
      ),
    );
  }
}
