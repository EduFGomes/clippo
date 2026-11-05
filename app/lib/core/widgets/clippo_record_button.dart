import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Botão redondo de gravar sobre a câmera, com legenda opcional embaixo. Só na Gravação.
class ClippoRecordButton extends StatefulWidget {
  const ClippoRecordButton({
    super.key,
    this.caption,
    this.semanticLabel = 'Iniciar gravação',
    required this.onPressed,
  });

  /// Legenda opcional embaixo do botão. Quando presente, também é o rótulo de acessibilidade.
  final String? caption;
  final String semanticLabel;

  final VoidCallback? onPressed;

  @override
  State<ClippoRecordButton> createState() => _ClippoRecordButtonState();
}

class _ClippoRecordButtonState extends State<ClippoRecordButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: active,
      label: widget.caption ?? widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: active ? (_) => _setPressed(true) : null,
        onTapUp: active ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        child: Opacity(
          opacity: active ? 1 : ClippoOpacity.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(ClippoSize.recordRing),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ClippoBrand.captureRecordRing, width: ClippoSize.recordRing),
                ),
                child: Container(
                  width: ClippoSize.recordButton,
                  height: ClippoSize.recordButton,
                  decoration: BoxDecoration(
                    color: _pressed ? ClippoBrand.wineDeep : ClippoBrand.wine,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const ClippoSvgIcon('capture', color: ClippoBrand.onWine, size: ClippoSize.recordIcon),
                ),
              ),
              if (widget.caption != null && widget.caption!.isNotEmpty) ...[
                const SizedBox(height: ClippoSpace.spaceM),
                Text(
                  widget.caption!,
                  textAlign: TextAlign.center,
                  style: ClippoText.label.copyWith(color: ClippoBrand.captureTextMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
