import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_pressable.dart';

/// Cabeçalho do perfil: avatar grande (foto ou iniciais), opção de editar foto, nome e @usuário.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.username,
    this.photoUrl,
    this.onEditPhoto,
    this.photoBusy = false,
  });

  final String name;
  final String username;

  /// Foto da pessoa (ex.: a da conta Google). Sem foto, ficam as iniciais.
  final String? photoUrl;
  final VoidCallback? onEditPhoto;

  /// A foto está subindo: o botão mostra "Enviando foto…" e não aceita outro toque.
  final bool photoBusy;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final url = photoUrl;
    final photo = url == null || url.isEmpty ? null : url;
    return Container(
      padding: const EdgeInsets.all(ClippoSpace.spaceL),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: ClippoSize.buttonHeight,
                  height: ClippoSize.buttonHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.controlSoft,
                    border: Border.all(color: colors.accent, width: ClippoSize.border),
                    image: photo != null
                        ? DecorationImage(
                            image: NetworkImage(ClippoAvatar.resolveUrl(photo)),
                            fit: BoxFit.cover,
                            onError: (_, _) {},
                          )
                        : null,
                  ),
                  child: photo != null
                      ? null
                      : Text(
                          _initials,
                          textScaler: TextScaler.noScaling,
                          style: ClippoText.titleS.copyWith(color: colors.accent),
                        ),
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceL),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: ClippoText.titleS.copyWith(color: colors.text)),
                      const SizedBox(height: ClippoSpace.labelToValue),
                      Text('@$username', style: ClippoText.body.copyWith(color: colors.textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sem [onEditPhoto] (catálogo, sem login), o botão não aparece.
          if (onEditPhoto != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Semantics(
              button: true,
              enabled: !photoBusy,
              label: photoBusy ? 'Enviando foto' : (photo == null ? 'Adicionar foto' : 'Trocar foto'),
              excludeSemantics: true,
              child: ClippoPressable(
                onTap: photoBusy ? null : onEditPhoto,
                child: Container(
                  constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClippoSpace.spaceL,
                    vertical: ClippoSpace.fieldPaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: colors.controlSoft,
                    borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    photoBusy ? 'Enviando foto…' : (photo == null ? 'Adicionar foto' : 'Trocar foto'),
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: colors.accent),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
