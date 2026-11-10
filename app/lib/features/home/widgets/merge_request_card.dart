import 'package:flutter/material.dart';

import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';

/// Um pedido para juntar duas sessões do mesmo jogo (D18), na Início e na Sessão.
///
/// Quem recebeu (dono da sessão de origem) vê Aceitar / Recusar; quem pediu vê que
/// está esperando e pode desistir. As duas saídas negativas chamam o mesmo
/// `cancelSessionMerge`.
class MergeRequestCard extends StatelessWidget {
  const MergeRequestCard({
    super.key,
    required this.request,
    required this.viewerId,
    required this.onAccept,
    required this.onCancel,
    this.busy = false,
  });

  final SessionMergeRequest request;

  /// Quem está vendo: decide se o cartão é "recebido" ou "enviado".
  final String viewerId;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  /// Esperando a resposta do servidor: trava os botões.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final incoming = request.waitsFor(viewerId);
    final title = incoming ? 'Juntar sessões?' : 'Esperando o outro dono';
    final message = incoming
        ? 'Pediram para juntar ${_quoted(request.fromName)} a ${_quoted(request.intoName)}. '
            'Os lances das duas viram uma sessão só.'
        : 'Você pediu para juntar ${_quoted(request.fromName)} a ${_quoted(request.intoName)}. '
            'Os lances juntam quando o dono aceitar.';

    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          border: incoming ? Border.all(color: colors.accent, width: ClippoSize.border) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(ClippoSpace.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: ClippoText.titleS.copyWith(color: incoming ? colors.accent : colors.text),
              ),
              const SizedBox(height: ClippoSpace.spaceS),
              Text(message, style: ClippoText.body.copyWith(color: colors.textMuted)),
              const SizedBox(height: ClippoSpace.spaceL),
              if (incoming) ...[
                ClippoPrimaryButton(
                  label: 'Aceitar',
                  onPressed: onAccept,
                  enabled: !busy,
                  loading: busy,
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                ClippoTextButton(label: 'Recusar', onPressed: busy ? null : onCancel),
              ] else
                ClippoTextButton(label: 'Desistir', onPressed: busy ? null : onCancel),
            ],
          ),
        ),
      ),
    );
  }

  static String _quoted(String name) => name.trim().isEmpty ? 'a outra sessão' : '“${name.trim()}”';
}
