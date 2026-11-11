import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';

/// Medidor abaixo do campo de senha nova: um traço por exigência (8+ caracteres, maiúscula,
/// minúscula e número), aceso quando ela foi cumprida. A legenda diz o que ainda falta.
class ClippoPasswordMeter extends StatelessWidget {
  const ClippoPasswordMeter({super.key, required this.password});

  /// A senha digitada até agora.
  final String password;

  /// O que falta, na ordem em que a pessoa lê, ou "Pronto".
  static String caption(String password) {
    final c = passwordChecks(password);
    if (!c.length) return '$passwordMin+ caracteres';
    if (!c.upper) return 'falta maiúscula';
    if (!c.lower) return 'falta minúscula';
    if (!c.number) return 'falta número';
    return 'Pronto';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final c = passwordChecks(password);
    final met = [c.length, c.upper, c.lower, c.number];
    final text = caption(password);
    final ready = !met.contains(false);
    final duration = ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(ClippoSpace.spaceS, ClippoSpace.spaceM, ClippoSpace.spaceS, 0),
      child: Row(
        children: [
          Expanded(
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 0; i < met.length; i++) ...[
                    if (i > 0) const SizedBox(width: ClippoSpace.spaceXs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: duration,
                        curve: ClippoMotion.standard,
                        height: ClippoSize.meter,
                        decoration: BoxDecoration(
                          color: met[i] ? colors.accent : colors.line,
                          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: ClippoSpace.spaceM),
          // A legenda muda enquanto a pessoa digita: o leitor de tela avisa o que falta.
          Semantics(
            liveRegion: true,
            child: Text(
              text,
              style: ClippoText.label.copyWith(color: ready ? colors.accent : colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
