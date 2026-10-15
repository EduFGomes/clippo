import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Título da tela em Anton, duas linhas (a segunda em accent), com subtítulo opcional.
/// Escreva o texto normal: o componente põe em MAIÚSCULAS.
class ClippoScreenTitle extends StatelessWidget {
  const ClippoScreenTitle({super.key, required this.line1, required this.line2, this.subtitle});

  final String line1;
  final String line2;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: line1.toUpperCase(), style: TextStyle(color: colors.text)),
                const TextSpan(text: '\n'),
                TextSpan(text: line2.toUpperCase(), style: TextStyle(color: colors.accent)),
              ],
            ),
            style: ClippoText.displayL,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: ClippoSpace.titleToSubtitle),
          Text(subtitle!, style: ClippoText.bodyL.copyWith(color: colors.textMuted)),
        ],
      ],
    );
  }
}
