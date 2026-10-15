import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Tela provisória: marca o lugar onde uma tela de verdade vai ficar.
/// Substitua pelo layout real seguindo a seção indicada de docs/produto.md.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.docSection,
  });

  /// Nome da tela como aparece na interface.
  final String title;

  /// Onde a tela está descrita, por exemplo "produto.md · 4.2 Início".
  final String docSection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(ClippoSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ClippoText.displayL.copyWith(color: colors.text)),
            const SizedBox(height: ClippoSpace.section),
            Text(
              'Tela provisória. Referência: $docSection',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
