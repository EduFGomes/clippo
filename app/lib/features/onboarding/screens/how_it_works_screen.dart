import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_step_list.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';

/// Entrada · Como funciona: o gesto em 3 passos (docs/produto.md › 4.1).
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key, this.enterFromWelcome = false});

  /// Veio do "Começar" da boas-vindas: entra com o vinho se desfazendo.
  final bool enterFromWelcome;

  static const _steps = [
    ClippoStep(title: 'Apoie o celular', description: 'Em qualquer canto da quadra, de frente para o jogo.'),
    ClippoStep(title: 'Jogue normalmente', description: 'O Clippo guarda sempre os últimos 30 segundos.'),
    ClippoStep(
      title: 'Fez um lance bom?',
      titleAccent: r'\ o /',
      description: 'Levante os dois braços para a câmera e o lance fica salvo.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      enterFromWelcome: enterFromWelcome,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(
            label: 'Criar conta',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: 'Já tenho conta',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Navigator.of(context).canPop()) ...[
            const ClippoBackButton(),
            const SizedBox(height: ClippoSpace.section),
          ],
          const ClippoScreenTitle(line1: 'Três passos.', line2: 'Zero toques.'),
          const SizedBox(height: ClippoSpace.sectionL),
          const ClippoStepList(steps: _steps, highlightIndex: 2),
        ],
      ),
    );
  }
}
