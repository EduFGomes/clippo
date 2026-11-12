import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';
import 'package:clippo/core/widgets/clippo_pressable.dart';

/// Voltar no topo das telas: círculo suave com chevron. Sem [onPressed], volta uma tela.
class ClippoBackButton extends StatelessWidget {
  const ClippoBackButton({super.key, this.onPressed, this.label});

  final VoidCallback? onPressed;

  /// Texto opcional ao lado do círculo (ex.: "Sessões" na tela Sessão).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final text = label;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: text == null || text.isEmpty ? 'Voltar' : 'Voltar para $text',
        child: ExcludeSemantics(
          child: ClippoPressable(
            onTap: onPressed ?? () => Navigator.of(context).maybePop(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: ClippoSize.minTouchTarget,
                minHeight: ClippoSize.minTouchTarget,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: ClippoSize.control,
                    height: ClippoSize.control,
                    decoration: BoxDecoration(color: colors.controlSoft, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: ClippoIcon(
                      ClippoIconShape.chevronLeft,
                      size: ClippoSize.backIcon,
                      color: colors.text,
                    ),
                  ),
                  if (text != null && text.isNotEmpty) ...[
                    const SizedBox(width: ClippoSpace.spaceM),
                    Flexible(
                      child: Text(
                        text,
                        style: ClippoText.label.copyWith(color: colors.textMuted),
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
