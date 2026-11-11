import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Atalho em pílula ao lado do título da tela ("Convidar" em Amigos, "Gravar" na Início):
/// contorno e texto em `accent` sobre `accentSoft`, com ícone. Área de toque de 48 dp.
class ClippoPillButton extends StatelessWidget {
  const ClippoPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final String label;

  /// Nome de um SVG de assets/icons/ ("plus", "capture"…).
  final String icon;
  final VoidCallback? onPressed;

  /// Rótulo de acessibilidade, quando o texto sozinho não basta ("Convidar amigo").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
          child: Center(
            widthFactor: 1,
            child: Opacity(
              opacity: enabled ? 1 : ClippoOpacity.disabled,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  border: Border.all(color: colors.accent, width: ClippoSize.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL, vertical: ClippoSpace.spaceM),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClippoSvgIcon(icon, size: ClippoSize.checkIcon, color: colors.accent),
                      const SizedBox(width: ClippoSpace.spaceS),
                      Text(label, style: ClippoText.label.copyWith(color: colors.accent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
