import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Linha centralizada com pergunta + link no rodapé (ex.: "Já tem conta?" + "Entrar").
/// A linha inteira é tocável.
class ClippoLinkLine extends StatelessWidget {
  const ClippoLinkLine({super.key, required this.prefix, required this.action, required this.onPressed});

  final String prefix;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: '$prefix $action',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: ClippoSize.textButtonHeight),
          alignment: Alignment.center,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$prefix ', style: ClippoText.bodyL.copyWith(color: colors.textMuted)),
                TextSpan(text: action, style: ClippoText.linkStrong.copyWith(color: colors.accent)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
