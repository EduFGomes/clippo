import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Um passo da [ClippoStepList]. [titleAccent] é um trecho final do título pintado em accent (ex.: "\ o /").
class ClippoStep {
  const ClippoStep({required this.title, required this.description, this.titleAccent});

  final String title;
  final String? titleAccent;
  final String description;
}

/// Passos numerados ligados por uma linha (ex.: "Como funciona"), com um passo em destaque.
class ClippoStepList extends StatelessWidget {
  const ClippoStepList({super.key, required this.steps, this.highlightIndex});

  final List<ClippoStep> steps;

  /// Índice (a partir de 0) do passo preenchido em accent.
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    // Centraliza a 1ª linha do título com o círculo, respeitando o tamanho de fonte do sistema.
    final titleLine = MediaQuery.textScalerOf(context).scale(ClippoText.titleS.fontSize!) * ClippoText.titleS.height!;
    final titleTop = ((ClippoSize.step - titleLine) / 2).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, step) in steps.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: ClippoSize.step,
                  child: Column(
                    children: [
                      _Circle(number: index + 1, highlighted: index == highlightIndex),
                      if (index < steps.length - 1)
                        Expanded(child: Container(width: ClippoSize.border, color: colors.line)),
                    ],
                  ),
                ),
                const SizedBox(width: ClippoSpace.spaceL),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: titleTop,
                      bottom: index < steps.length - 1 ? ClippoSpace.stepGap : 0,
                    ),
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              text: step.title,
                              children: [
                                if (step.titleAccent != null)
                                  TextSpan(text: ' ${step.titleAccent}', style: TextStyle(color: colors.accent)),
                              ],
                            ),
                            style: ClippoText.titleS.copyWith(color: colors.text),
                          ),
                          const SizedBox(height: ClippoSpace.spaceS),
                          Text(step.description, style: ClippoText.body.copyWith(color: colors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.number, required this.highlighted});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return ExcludeSemantics(
      child: Container(
        width: ClippoSize.step,
        height: ClippoSize.step,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlighted ? colors.accent : null,
          border: highlighted ? null : Border.all(color: colors.outline, width: ClippoSize.border),
        ),
        child: Text(
          '$number',
          textScaler: TextScaler.noScaling, // o número precisa caber no círculo
          style: ClippoText.stepNumber.copyWith(
            color: highlighted ? colors.onPrimary : colors.text,
            fontFeatures: ClippoText.tabular,
          ),
        ),
      ),
    );
  }
}
