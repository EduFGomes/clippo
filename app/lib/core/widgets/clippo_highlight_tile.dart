import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Card de highlight na tela Sessão (docs/produto.md › 4.3).
///
/// Pensado para grade de 2 colunas (para ver mais takes ao mesmo tempo):
/// miniatura no topo com botão de play centralizado e, abaixo, o título
/// do lance e o momento na sessão ("00:12:40 · 30s" ou "00:12:40 · enviando…").
class ClippoHighlightTile extends StatelessWidget {
  const ClippoHighlightTile({
    super.key,
    required this.title,
    required this.timing,
    required this.onTap,
    this.thumbnail,
    this.uploading = false,
    this.onRename,
  });

  /// Título curto do lance ("Lance 3", ou o nome que o dono deu).
  final String title;

  /// Momento e duração formatados ("00:12:40 · 30s" ou "00:12:40 · enviando…").
  final String timing;

  /// O quadro do vídeo, quando já disponível (um `FileImage` da miniatura no aparelho ou já
  /// baixada). Sem ele, ou se a imagem não abrir, desenha o quadro da quadra.
  final ImageProvider? thumbnail;

  /// Destaca a linha de tempo quando o vídeo ainda está subindo (R13).
  final bool uploading;

  final VoidCallback onTap;

  /// "Editar lance" (renomear ou apagar): um lápis ao lado do título. Só para o dono da sessão; nulo esconde.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final timingColor = uploading ? colors.accent : colors.textMuted;

    final rename = onRename;
    return Semantics(
      button: true,
      label: '$title, $timing',
      customSemanticsActions: rename == null
          ? null
          : {const CustomSemanticsAction(label: 'Editar lance'): rename},
      child: ExcludeSemantics(
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    ClippoSpace.spaceS,
                    ClippoSpace.spaceS,
                    ClippoSpace.spaceS,
                    0,
                  ),
                  child: _Thumbnail(image: thumbnail),
                ),
                Padding(
                  padding: const EdgeInsets.all(ClippoSpace.spaceM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: ClippoText.titleS.copyWith(color: colors.text),
                            ),
                          ),
                          if (rename != null)
                            GestureDetector(
                              key: const ValueKey('clippo-highlight-rename'),
                              behavior: HitTestBehavior.opaque,
                              onTap: rename,
                              // Área de toque do tamanho mínimo; o lápis fica no canto, alinhado ao título.
                              child: SizedBox.square(
                                dimension: ClippoSize.minTouchTarget,
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: ClippoSvgIcon('edit', size: ClippoSize.checkIcon, color: colors.textMuted),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: ClippoSpace.spaceXs),
                      Row(
                        children: [
                          ClippoSvgIcon(
                            'clock',
                            size: ClippoSize.checkIcon,
                            color: timingColor,
                          ),
                          const SizedBox(width: ClippoSpace.spaceXs),
                          Expanded(
                            child: Text(
                              timing,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ClippoText.label.copyWith(
                                color: timingColor,
                                fontFeatures: ClippoText.tabular,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.image});

  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final photo = image;
    final court = CustomPaint(painter: _CourtPreviewPainter(lineColor: colors.outline));

    return SizedBox(
      height: ClippoSize.thumbnailHeight,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField - ClippoSpace.spaceXs),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: ColoredBox(color: colors.backgroundGlow)),
            Positioned.fill(
              child: photo == null
                  ? court
                  : Image(
                      image: photo,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      // Enquanto a imagem não chega, e se ela não abrir: o desenho de quadra.
                      frameBuilder: (_, child, frame, loadedNow) =>
                          frame == null && !loadedNow ? court : child,
                      errorBuilder: (_, _, _) => court,
                    ),
            ),
            Container(
              width: ClippoSize.playBadge,
              height: ClippoSize.playBadge,
              decoration: const BoxDecoration(
                color: ClippoBrand.captureOverlay,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const ClippoSvgIcon(
                'play',
                size: ClippoSize.checkIcon,
                color: ClippoBrand.onWine,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Linhas discretas de quadra para quando a miniatura real ainda não carregou.
class _CourtPreviewPainter extends CustomPainter {
  const _CourtPreviewPainter({required this.lineColor});

  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final horizon = size.height * 0.34;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.92)
      ..lineTo(size.width * 0.26, horizon)
      ..lineTo(size.width * 0.74, horizon)
      ..lineTo(size.width * 0.92, size.height * 0.92);
    canvas.drawPath(path, paint);

    canvas.drawLine(
      Offset(size.width * 0.17, size.height * 0.62),
      Offset(size.width * 0.83, size.height * 0.62),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.62),
        width: size.width * 0.24,
        height: size.height * 0.16,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CourtPreviewPainter oldDelegate) => oldDelegate.lineColor != lineColor;
}
