import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Base de tudo que é tocável e não é botão primário: chips, pílulas, voltar, ✕ e os ícones do
/// Player. Enquanto o dedo está em cima, o conteúdo fica a [ClippoOpacity.pressed] — o app é
/// plano, sem ripple (`clippoTheme`), então é assim que a pessoa vê que o toque pegou.
///
/// Sem [onTap], não reage. A área de toque é a do [child]: quem usa garante os 48 dp
/// (`ClippoSize.minTouchTarget`).
class ClippoPressable extends StatefulWidget {
  const ClippoPressable({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<ClippoPressable> createState() => _ClippoPressableState();
}

class _ClippoPressableState extends State<ClippoPressable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      child: AnimatedOpacity(
        opacity: _pressed ? ClippoOpacity.pressed : 1,
        duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.press,
        curve: ClippoMotion.standard,
        child: widget.child,
      ),
    );
  }
}
