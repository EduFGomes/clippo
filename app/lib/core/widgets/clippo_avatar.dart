import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Foto de uma pessoa, redonda. Sem foto, mostra a inicial do nome.
/// Use [ClippoAvatarRow] quando forem vários lado a lado.
class ClippoAvatar extends StatelessWidget {
  const ClippoAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = ClippoSize.avatar,
    this.ring,
  });

  /// Nome de quem aparece. A inicial é o que se vê quando não há foto.
  final String name;

  final String? photoUrl;
  final double size;

  /// Anel da cor do fundo onde o avatar está, para separar um do outro
  /// quando eles se sobrepõem na fileira.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final ringWidth = ring == null ? 0.0 : ClippoSize.border;
    final photo = photoUrl;

    return Semantics(
      label: name.isEmpty ? null : name,
      child: Container(
        width: size + ringWidth * 2,
        height: size + ringWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring,
        ),
        child: Padding(
          padding: EdgeInsets.all(ringWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.controlSoft,
              image: photo == null || photo.isEmpty
                  ? null
                  : DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover),
            ),
            // A inicial fica embaixo da foto: se a imagem não carregar, ela aparece.
            child: Center(
              child: Text(
                _initial,
                style: ClippoText.label.copyWith(
                  color: photo == null || photo.isEmpty ? colors.textMuted : Colors.transparent,
                  fontSize: size * 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _initial {
    final clean = name.trim();
    return clean.isEmpty ? '?' : clean.characters.first.toUpperCase();
  }
}

/// Os participantes de uma sessão, um cobrindo o anterior, com "+N" no fim
/// quando sobra gente (docs/produto.md › 4.2: até 5 avatares + "+N").
class ClippoAvatarRow extends StatelessWidget {
  const ClippoAvatarRow({
    super.key,
    required this.people,
    this.hidden = 0,
    this.size = ClippoSize.avatar,
    this.ring,
  });

  /// Quem aparece desenhado, na ordem. Passe no máximo os que cabem.
  final List<ClippoAvatarPerson> people;

  /// Quantos ficaram de fora. 0 esconde o "+N".
  final int hidden;

  final double size;

  /// Cor do fundo atrás da fileira, usada no anel que separa um avatar do outro.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final ringColor = ring ?? colors.surface;
    final step = size - ClippoSpace.avatarOverlap;

    return Semantics(
      container: true,
      label: _semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          height: size + ClippoSize.border * 2,
          width: people.isEmpty && hidden == 0 ? 0 : step * (people.length + (hidden > 0 ? 1 : 0)) + ClippoSpace.avatarOverlap,
          child: Stack(
            children: [
              for (var i = 0; i < people.length; i++)
                Positioned(
                  left: i * step,
                  child: ClippoAvatar(
                    name: people[i].name,
                    photoUrl: people[i].photoUrl,
                    size: size,
                    ring: ringColor,
                  ),
                ),
              if (hidden > 0)
                Positioned(
                  left: people.length * step,
                  child: _More(count: hidden, size: size, ring: ringColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _semanticLabel {
    final names = people.map((p) => p.name).where((n) => n.isNotEmpty).join(', ');
    if (hidden == 0) return names;
    return names.isEmpty ? 'mais $hidden' : '$names e mais $hidden';
  }
}

/// Uma pessoa desenhada pela [ClippoAvatarRow]. Fica aqui para o componente não
/// precisar conhecer o modelo de dados.
class ClippoAvatarPerson {
  const ClippoAvatarPerson({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;
}

class _More extends StatelessWidget {
  const _More({required this.count, required this.size, required this.ring});

  final int count;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Container(
      width: size + ClippoSize.border * 2,
      height: size + ClippoSize.border * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: Padding(
        padding: const EdgeInsets.all(ClippoSize.border),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.controlSoft),
          child: Center(
            child: Text(
              '+$count',
              style: ClippoText.label.copyWith(color: colors.textMuted, fontSize: size * 0.34),
            ),
          ),
        ),
      ),
    );
  }
}
