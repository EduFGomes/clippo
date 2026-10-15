import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Medidor abaixo do campo de senha: um traço aceso por caractere, até 6.
class ClippoPasswordMeter extends StatelessWidget {
  const ClippoPasswordMeter({super.key, required this.length});

  /// Quantidade de caracteres digitados na senha.
  final int length;

  /// Mínimo exigido pelo Firebase Auth.
  static const int minLength = 6;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final lit = math.min(length, minLength);
    final ready = length >= minLength;
    final duration = ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus;

    // O requisito já está no hint do campo; o medidor é só visual.
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(ClippoSpace.spaceS, ClippoSpace.spaceM, ClippoSpace.spaceS, 0),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < minLength; i++) ...[
                    if (i > 0) const SizedBox(width: ClippoSpace.spaceXs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: duration,
                        curve: ClippoMotion.standard,
                        height: ClippoSize.meter,
                        decoration: BoxDecoration(
                          color: i < lit ? colors.accent : colors.line,
                          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceM),
            Text(
              ready ? 'Pronto' : '6+ caracteres',
              style: ClippoText.label.copyWith(color: ready ? colors.accent : colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
