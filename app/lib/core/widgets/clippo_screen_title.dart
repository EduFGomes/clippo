import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Título da tela em Anton, duas linhas (a segunda em accent), com subtítulo opcional.
/// Escreva o texto normal: o componente põe em MAIÚSCULAS.
///
/// [line1] vazio = título de uma linha só, em accent ("PELADA."). Quando uma linha não cabe
/// na largura em `displayL`, o título desce para `displayM` e depois `displayS`, para um nome
/// longo não virar quatro ou cinco linhas; em `displayS` ele quebra normalmente.
class ClippoScreenTitle extends StatelessWidget {
  const ClippoScreenTitle({super.key, required this.line1, required this.line2, this.subtitle});

  final String line1;
  final String line2;
  final String? subtitle;

  /// Do maior para o menor: o primeiro em que cada linha cabe inteira na largura.
  static final List<TextStyle> _sizes = [ClippoText.displayL, ClippoText.displayM, ClippoText.displayS];

  static TextStyle _fitting(List<String> lines, double maxWidth, TextScaler scaler) {
    for (final style in _sizes) {
      final fits = lines.every((line) {
        final painter = TextPainter(
          text: TextSpan(text: line, style: style),
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width <= maxWidth;
      });
      if (fits) return style;
    }
    return _sizes.last;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final first = line1.trim().toUpperCase();
    final second = line2.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(
          builder: (context) {
            // A largura do conteúdo do ClippoScreenGround (tela menos as margens). Sem
            // LayoutBuilder: as telas com rodapé medem a altura (IntrinsicHeight) e ele não deixa.
            final width = MediaQuery.sizeOf(context).width - 2 * ClippoSpace.gutter;
            final style = _fitting(
              [if (first.isNotEmpty) first, second],
              width,
              MediaQuery.textScalerOf(context),
            );
            return Semantics(
              header: true,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (first.isNotEmpty) ...[
                      TextSpan(text: first, style: TextStyle(color: colors.text)),
                      const TextSpan(text: '\n'),
                    ],
                    TextSpan(text: second, style: TextStyle(color: colors.accent)),
                  ],
                ),
                style: style,
              ),
            );
          },
        ),
        if (subtitle != null) ...[
          const SizedBox(height: ClippoSpace.titleToSubtitle),
          Text(subtitle!, style: ClippoText.bodyL.copyWith(color: colors.textMuted)),
        ],
      ],
    );
  }
}
