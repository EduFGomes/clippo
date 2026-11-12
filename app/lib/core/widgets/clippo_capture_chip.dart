import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_pressable.dart';

/// Chip de escolha sobre a câmera ("Gravar sozinho", "Com Rafa") e nos participantes da sessão.
///
/// [ClippoCaptureChip.themed] é o mesmo chip fora da câmera ("Confirme a sessão"): segue o tema
/// claro ou escuro, porque o translúcido claro sumiria sobre um fundo claro.
class ClippoCaptureChip extends StatelessWidget {
  const ClippoCaptureChip({super.key, required this.label, required this.selected, required this.onPressed})
      : themed = false;

  const ClippoCaptureChip.themed({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  }) : themed = true;

  final String label;

  /// Selecionado: pêssego com texto escuro (no tema: `primary` com `onPrimary`). Senão:
  /// translúcido com borda (no tema: `surface` com borda `outline`).
  final bool selected;

  final VoidCallback? onPressed;

  /// Segue o tema em vez das cores fixas da câmera.
  final bool themed;

  @override
  Widget build(BuildContext context) {
    final colors = themed ? ClippoColors.of(context) : null;
    final fill = colors == null
        ? (selected ? ClippoBrand.peach : ClippoBrand.captureChip)
        : (selected ? colors.primary : colors.surface);
    final border = colors == null
        ? (selected ? ClippoBrand.peach : ClippoBrand.captureChipBorder)
        : (selected ? colors.primary : colors.outline);
    final text = colors == null
        ? (selected ? ClippoBrand.onPeach : ClippoBrand.onWine)
        : (selected ? colors.onPrimary : colors.text);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: ClippoPressable(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus,
              curve: ClippoMotion.standard,
              constraints: const BoxConstraints(minHeight: ClippoSize.captureChip),
              padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                border: Border.all(color: border, width: ClippoSize.border),
              ),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: ClippoText.label.copyWith(color: text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
