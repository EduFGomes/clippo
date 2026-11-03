import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Card de highlight na tela Sessão (docs/produto.md › 4.3).
///
/// Pensado para grade de 2 colunas (para ver mais takes ao mesmo tempo):
/// miniatura no topo com botão de play centralizado e, abaixo, o título criativo
/// do lance e o momento na sessão ("00:12:40 · 30s" ou "00:12:40 · enviando…").
class ClippoHighlightTile extends StatelessWidget {
  const ClippoHighlightTile({
    super.key,
    required this.title,
    required this.timing,
    required this.onTap,
    this.thumbnailUrl,
    this.uploading = false,
  });

  /// Título curto e criativo do lance ("Jogada de cinema", "Ponto antológico").
  final String title;

  /// Momento e duração formatados ("00:12:40 · 30s" ou "00:12:40 · enviando…").
  final String timing;

  /// URL da miniatura, quando já disponível. Sem ela, desenha o quadro da quadra.
  final String? thumbnailUrl;

  /// Destaca a linha de tempo quando o vídeo ainda está subindo (R13).
  final bool uploading;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final timingColor = uploading ? colors.accent : colors.textMuted;

    return Semantics(
      button: true,
      label: '$title, $timing',
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
                  child: _Thumbnail(thumbnailUrl: thumbnailUrl),
                ),
                Padding(
                  padding: const EdgeInsets.all(ClippoSpace.spaceM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ClippoText.titleS.copyWith(color: colors.text),
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
  const _Thumbnail({this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final photo = thumbnailUrl;

    return SizedBox(
      height: ClippoSize.thumbnailHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundGlow,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField - ClippoSpace.spaceXs),
          image: photo == null || photo.isEmpty
              ? null
              : DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (photo == null || photo.isEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: _CourtPreviewPainter(lineColor: colors.outline),
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
