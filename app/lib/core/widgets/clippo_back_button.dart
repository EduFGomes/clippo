import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';

/// Voltar no topo das telas: círculo suave com chevron. Sem [onPressed], volta uma tela.
class ClippoBackButton extends StatelessWidget {
  const ClippoBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: 'Voltar',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed ?? () => Navigator.of(context).maybePop(),
          child: SizedBox.square(
            dimension: ClippoSize.minTouchTarget,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: ClippoSize.control,
                height: ClippoSize.control,
                decoration: BoxDecoration(color: colors.controlSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: ClippoIcon(ClippoIconShape.chevronLeft, size: ClippoSize.backIcon, color: colors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
