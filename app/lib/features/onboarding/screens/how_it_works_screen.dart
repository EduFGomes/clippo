import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';
import 'package:clippo/features/onboarding/widgets/onboarding_scaffold.dart';

/// Entrada · 2. Como funciona: o gesto em até 3 passos (docs/produto.md › 4.1).
/// Provisório: só texto. A versão final mostra o gesto com traço outline ou vídeo curto.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const _steps = [
    ('Apoie o celular', 'Em qualquer canto da quadra, de frente para o jogo.'),
    ('Jogue normalmente', 'O Clippo guarda sempre os últimos 30 segundos.'),
    (r'Fez um lance bom? \ o /', 'Levante os dois braços para a câmera e o lance fica salvo.'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return OnboardingScaffold(
      title: 'Como funciona',
      primaryLabel: 'Criar conta',
      onPrimary: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, step) in _steps.indexed) ...[
            Text('${index + 1}. ${step.$1}', style: ClippoText.itemTitle.copyWith(color: colors.text)),
            const SizedBox(height: 4),
            Text(step.$2, style: ClippoText.bodyText.copyWith(color: colors.textMuted)),
            const SizedBox(height: ClippoSpace.sectionGap),
          ],
        ],
      ),
    );
  }
}
