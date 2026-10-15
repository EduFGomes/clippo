import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Estrutura comum das telas de entrada (docs/produto.md › 4.1):
/// fundo do tema, título screenTitle, conteúdo e UM botão primário no rodapé.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.loading = false,
    this.secondary,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String primaryLabel;

  /// null desativa o botão.
  final VoidCallback? onPrimary;
  final bool loading;

  /// Ação secundária opcional abaixo do botão (ex.: "Já tenho conta").
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return Scaffold(
      appBar: Navigator.of(context).canPop() ? AppBar() : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ClippoSpace.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: ClippoText.displayL.copyWith(color: colors.text)),
              if (subtitle != null) ...[
                const SizedBox(height: ClippoSpace.spaceM),
                Text(subtitle!, style: ClippoText.body.copyWith(color: colors.textMuted)),
              ],
              const SizedBox(height: ClippoSpace.section),
              Expanded(child: SingleChildScrollView(child: child)),
              const SizedBox(height: ClippoSpace.spaceM),
              SizedBox(
                height: ClippoSize.buttonHeight,
                child: FilledButton(
                  onPressed: loading ? null : onPrimary,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    textStyle: ClippoText.button,
                  ),
                  child: loading
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(primaryLabel),
                ),
              ),
              if (secondary != null) ...[
                const SizedBox(height: ClippoSpace.spaceM),
                Center(child: secondary!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
