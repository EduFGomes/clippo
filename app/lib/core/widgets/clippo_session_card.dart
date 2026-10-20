import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';

/// Um jogo na lista da Início, em sanfona (docs/produto.md › 4.2).
///
/// Fechado: nome, data e quantos highlights. Aberto: local, participantes,
/// duração e a ação de ver os highlights. Quem decide qual card está aberto é a
/// tela — só um por vez —, por isso [expanded] e [onToggle] vêm de fora.
///
/// Recebe texto já formatado (use core/format/clippo_format.dart), não o modelo:
/// assim o componente serve para qualquer lista parecida.
class ClippoSessionCard extends StatelessWidget {
  const ClippoSessionCard({
    super.key,
    required this.title,
    required this.summary,
    required this.expanded,
    required this.onToggle,
    this.location,
    this.details,
    this.participants = const [],
    this.hiddenParticipants = 0,
    this.actionLabel = 'Ver highlights',
    this.onAction,
  });

  /// Nome da sessão ("Pelada de quinta").
  final String title;

  /// Linha de baixo quando fechado: "11 set 2026 · 7 highlights".
  final String summary;

  /// Local, mostrado só quando aberto. Vazio ou nulo some.
  final String? location;

  /// Duração e participantes quando aberto: "1h 42min · 10 participantes".
  final String? details;

  final List<ClippoAvatarPerson> participants;
  final int hiddenParticipants;

  final bool expanded;
  final VoidCallback onToggle;

  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, colors),
                  AnimatedSize(
                    duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.enable,
                    curve: ClippoMotion.standard,
                    alignment: Alignment.topCenter,
                    child: expanded
                        ? _body(context, colors)
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ClippoColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.labelToValue),
              Text(summary, style: ClippoText.label.copyWith(color: colors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: ClippoSpace.spaceM),
        // O chevron aponta para baixo quando fechado e vira para cima ao abrir.
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.enable,
          curve: ClippoMotion.standard,
          child: ClippoIcon(
            ClippoIconShape.chevronDown,
            size: ClippoSize.backIcon,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, ClippoColors colors) {
    final place = location;
    final info = details;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: ClippoSpace.spaceL),
        if (place != null && place.isNotEmpty) ...[
          Text(place, style: ClippoText.body.copyWith(color: colors.textMuted)),
          const SizedBox(height: ClippoSpace.spaceM),
        ],
        if (participants.isNotEmpty || hiddenParticipants > 0) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ClippoAvatarRow(
              people: participants,
              hidden: hiddenParticipants,
              ring: colors.surface,
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
        ],
        if (info != null && info.isNotEmpty) ...[
          Text(info, style: ClippoText.label.copyWith(color: colors.textMuted)),
          const SizedBox(height: ClippoSpace.spaceL),
        ],
        ClippoPrimaryButton(label: actionLabel, onPressed: onAction ?? () {}),
      ],
    );
  }
}
