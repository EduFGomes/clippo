import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Tela provisória: marca o lugar onde uma tela de verdade vai ficar.
/// Substitua pelo layout real seguindo a seção indicada de docs/03-telas.md.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.docSection,
  });

  /// Nome da tela como aparece na interface.
  final String title;

  /// Onde a tela está descrita, por exemplo "03-telas.md · 1. Início".
  final String docSection;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(ClippoSpace.screenGutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: ClippoText.screenTitle.copyWith(color: colors.text)),
            const SizedBox(height: ClippoSpace.sectionGap),
            Text(
              'Tela provisória. Referência: $docSection',
              style: ClippoText.bodyText.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
