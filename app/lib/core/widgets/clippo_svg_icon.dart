import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Um ícone da marca, dos SVGs de assets/icons/ (grade 24, traço 1,6).
///
/// Passe só o nome do arquivo, sem pasta nem extensão: `ClippoSvgIcon('home')`.
/// A lista está em docs/design.md › 3.6 Ícones. Os arquivos usam
/// `stroke="currentColor"`, então a cor vem daqui.
///
/// Para os ícones dos controles (voltar, olho, ✓), use o [ClippoIcon], que
/// desenha em código e não depende de asset.
class ClippoSvgIcon extends StatelessWidget {
  const ClippoSvgIcon(
    this.name, {
    super.key,
    required this.color,
    this.size = ClippoSize.icon,
    this.semanticLabel,
  });

  /// Nome do arquivo em assets/icons/, sem ".svg".
  final String name;

  final Color color;
  final double size;

  /// Só quando o ícone aparece sozinho, sem texto ao lado.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
