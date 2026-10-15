import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/onboarding/screens/how_it_works_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';
import 'package:clippo/features/onboarding/widgets/onboarding_scaffold.dart';

/// Entrada · 1. Boas-vindas (docs/produto.md › 4.1).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return OnboardingScaffold(
      title: 'Clippo',
      subtitle: 'Levantou os braços, o lance está salvo.',
      primaryLabel: 'Começar',
      onPrimary: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HowItWorksScreen()),
      ),
      secondary: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
        ),
        child: const Text('Já tenho conta'),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Center(
          child: Text(
            r'\ o /',
            style: ClippoText.heroMark.copyWith(color: colors.accent),
          ),
        ),
      ),
    );
  }
}
