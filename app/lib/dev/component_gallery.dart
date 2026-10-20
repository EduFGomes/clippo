import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_link_line.dart';
import 'package:clippo/core/widgets/clippo_password_meter.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_radial_nav.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_step_list.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// PROVISÓRIO: todos os componentes de core/widgets numa tela, com troca de tema,
/// para conferir os dois modos sem mexer no Android. Componente novo entra aqui.
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

class _ComponentGalleryState extends State<ComponentGallery> {
  Brightness? _brightness;
  bool _cardExpanded = true;
  final _plain = TextEditingController();
  final _withError = TextEditingController(text: 'nome com espaço');
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _plain.dispose();
    _withError.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? Theme.of(context).brightness;
    final other = brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    return Theme(
      data: clippoTheme(brightness),
      child: Builder(
        builder: (context) => Stack(
          children: [
            // A roda fica por cima, como no app. A folga embaixo evita que ela
            // cubra o fim da galeria.
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).padding.copyWith(
                  bottom: MediaQuery.of(context).padding.bottom + ClippoSize.navClearance,
                ),
              ),
              child: ClippoScreenGround(
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClippoPrimaryButton(label: 'Botão primário', onPressed: () {}),
                    const SizedBox(height: ClippoSpace.spaceS),
                    ClippoPrimaryButton(label: 'Desabilitado', onPressed: () {}, enabled: false),
                    const SizedBox(height: ClippoSpace.spaceS),
                    ClippoPrimaryButton(label: 'Carregando', onPressed: () {}, loading: true),
                    const SizedBox(height: ClippoSpace.spaceS),
                    ClippoTextButton(label: 'Botão de texto', onPressed: () {}),
                    ClippoLinkLine(prefix: 'Já tem conta?', action: 'Entrar', onPressed: () {}),
                    const SizedBox(height: ClippoSpace.spaceM),
                    ColoredBox(
                      color: ClippoBrand.wine,
                      child: Padding(
                        padding: const EdgeInsets.all(ClippoSpace.spaceL),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClippoPrimaryButton.onWine(label: 'Primário onWine', onPressed: () {}),
                            const SizedBox(height: ClippoSpace.spaceS),
                            ClippoTextButton.onWine(label: 'Texto onWine', onPressed: () {}),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const ClippoBackButton(),
                        const Spacer(),
                        ClippoTextButton(
                          label: other == Brightness.dark ? 'Ver no escuro' : 'Ver no claro',
                          onPressed: () => setState(() => _brightness = other),
                        ),
                      ],
                    ),
                    const SizedBox(height: ClippoSpace.section),
                    const ClippoScreenTitle(
                      line1: 'Galeria de',
                      line2: 'componentes.',
                      subtitle: 'Tudo de core/widgets.',
                    ),
                    const SizedBox(height: ClippoSpace.section),
                    ClippoTextField(label: 'Campo', hint: 'texto de exemplo', controller: _plain),
                    const SizedBox(height: ClippoSpace.spaceM),
                    ClippoTextField(
                      label: 'Campo com erro',
                      controller: _withError,
                      prefixText: '@',
                      errorText: 'Use só letras, números, "_" e ".".',
                    ),
                    const SizedBox(height: ClippoSpace.spaceM),
                    ClippoTextField.password(
                      label: 'Senha',
                      hint: 'mínimo de 6 caracteres',
                      controller: _password,
                    ),
                    ListenableBuilder(
                      listenable: _password,
                      builder: (context, _) => ClippoPasswordMeter(length: _password.text.length),
                    ),
                    const SizedBox(height: ClippoSpace.spaceM),
                    ClippoTextField.confirmation(
                      label: 'Confirme a senha',
                      hint: 'repita a senha',
                      controller: _confirm,
                      password: _password,
                    ),
                    const SizedBox(height: ClippoSpace.sectionL),
                    const ClippoAvatarRow(
                      people: [
                        ClippoAvatarPerson(name: 'Alice Prado'),
                        ClippoAvatarPerson(name: 'Bruno'),
                        ClippoAvatarPerson(name: 'Rafa'),
                      ],
                      hidden: 7,
                    ),
                    const SizedBox(height: ClippoSpace.spaceL),
                    ClippoSessionCard(
                      title: 'Pelada de quinta',
                      summary: '11 set 2026 · 7 highlights',
                      location: 'Quadra do Parque',
                      details: '1h 42min · 10 participantes',
                      participants: const [
                        ClippoAvatarPerson(name: 'Alice Prado'),
                        ClippoAvatarPerson(name: 'Bruno'),
                        ClippoAvatarPerson(name: 'Rafa'),
                      ],
                      hiddenParticipants: 7,
                      expanded: _cardExpanded,
                      onToggle: () => setState(() => _cardExpanded = !_cardExpanded),
                      onAction: () {},
                    ),
                    const SizedBox(height: ClippoSpace.sectionL),
                    const ClippoStepList(
                      highlightIndex: 2,
                      steps: [
                        ClippoStep(title: 'Primeiro passo', description: 'Descrição do passo.'),
                        ClippoStep(title: 'Segundo passo', description: 'Descrição do passo.'),
                        ClippoStep(
                          title: 'Passo em destaque',
                          titleAccent: r'\ o /',
                          description: 'Descrição do passo.',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: ClippoRadialNav(
                currentIndex: 0,
                onSelected: (_) {},
                items: const [
                  ClippoRadialNavItem(label: 'Início', icon: 'home'),
                  ClippoRadialNavItem(label: 'Gravar', icon: 'capture'),
                  ClippoRadialNavItem(label: 'Amigos', icon: 'friends'),
                  ClippoRadialNavItem(label: 'Perfil', icon: 'profile'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
