import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/features/onboarding/screens/how_it_works_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';

/// Entrada · Boas-vindas (docs/produto.md › 4.1). Fundo vinho nos dois temas.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  /// A tela seguinte aparece de uma vez, coberta de vinho, e o vinho se desfaz nela
  /// (ClippoScreenGround com enterFromWelcome).
  static Route<void> _wineRoute(Widget screen) => PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => screen,
      );

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: ClippoBrand.wine,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const padding = EdgeInsets.fromLTRB(
                ClippoSpace.gutter,
                ClippoSpace.welcomeTop,
                ClippoSpace.gutter,
                ClippoSpace.screenBottom,
              );
              return SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          header: true,
                          label: 'Clippo',
                          excludeSemantics: true,
                          child: Text('CLIPPO', style: ClippoText.wordmark.copyWith(color: ClippoBrand.onWine)),
                        ),
                        const Spacer(),
                        ExcludeSemantics(
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                r'\O/',
                                textScaler: TextScaler.noScaling, // é a marca, não texto de leitura
                                style: ClippoText.heroMark.copyWith(color: ClippoBrand.peach),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: ClippoSpace.welcomeHeroToPhrase),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Levantou os braços,'.toUpperCase(),
                                style: const TextStyle(color: ClippoBrand.onWine),
                              ),
                              const TextSpan(text: '\n'),
                              TextSpan(
                                text: 'o lance está salvo.'.toUpperCase(),
                                style: const TextStyle(color: ClippoBrand.peach),
                              ),
                            ],
                          ),
                          style: ClippoText.displayM,
                        ),
                        const SizedBox(height: ClippoSpace.welcomePhraseToActions),
                        ClippoPrimaryButton.onWine(
                          label: 'Começar',
                          onPressed: () => Navigator.of(context).push(
                            _wineRoute(const HowItWorksScreen(enterFromWelcome: true)),
                          ),
                        ),
                        const SizedBox(height: ClippoSpace.spaceS),
                        ClippoTextButton.onWine(
                          label: 'Já tenho conta',
                          onPressed: () => Navigator.of(context).push(
                            _wineRoute(const SignInScreen(enterFromWelcome: true)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
