import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';

/// Aviso no centro da tela preta da Gravação: "Highlight salvo", ou o erro ao salvar.
class ClippoCaptureToast extends StatelessWidget {
  const ClippoCaptureToast({super.key, required this.title, this.detail, this.success = true});

  final String title;

  /// Linha menor embaixo ("últimos 30s · gesto \ o / detectado").
  final String? detail;

  /// Com o ✓ pêssego em cima. Sem ele, o erro fica só no texto.
  final bool success;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (success) ...[
              Container(
                width: ClippoSize.check,
                height: ClippoSize.check,
                decoration: const BoxDecoration(color: ClippoBrand.peach, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const ClippoIcon(
                  ClippoIconShape.check,
                  size: ClippoSize.checkIcon,
                  color: ClippoBrand.onPeach,
                  stroke: ClippoSize.checkStroke,
                ),
              ),
              const SizedBox(height: ClippoSpace.spaceM),
            ],
            Text(title, textAlign: TextAlign.center, style: ClippoText.titleS.copyWith(color: ClippoBrand.onWine)),
            if (detail != null) ...[
              const SizedBox(height: ClippoSpace.spaceS),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
