import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';

/// Voltar no topo das telas: círculo suave com chevron (e rótulo opcional,
/// como "Amigos"). Sem [onPressed], volta uma tela.
class ClippoBackButton extends StatelessWidget {
  const ClippoBackButton({super.key, this.onPressed, this.label});

  final VoidCallback? onPressed;

  /// Rótulo opcional ao lado do círculo de voltar.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final circle = Container(
      width: ClippoSize.control,
      height: ClippoSize.control,
      decoration: BoxDecoration(color: colors.controlSoft, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: ClippoIcon(
        ClippoIconShape.chevronLeft,
        size: ClippoSize.backIcon,
        color: colors.text,
      ),
    );

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: label == null ? 'Voltar' : 'Voltar para $label',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed ?? () => Navigator.of(context).maybePop(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: ClippoSize.minTouchTarget,
                minHeight: ClippoSize.minTouchTarget,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  circle,
                  if (label != null) ...[
                    const SizedBox(width: ClippoSpace.spaceM),
                    Flexible(
                      child: Text(
                        label!,
                        overflow: TextOverflow.ellipsis,
                        style: ClippoText.body.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
