import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Ponto que pulsa devagar no centro da tela preta: a detecção está ligada. Só na Gravação.
class ClippoPulseDot extends StatefulWidget {
  const ClippoPulseDot({super.key});

  @override
  State<ClippoPulseDot> createState() => _ClippoPulseDotState();
}

class _ClippoPulseDotState extends State<ClippoPulseDot> with SingleTickerProviderStateMixin {
  // Meio ciclo para cada lado: cresce/acende e encolhe/apaga suavemente em standbyPulse.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClippoMotion.standbyPulse ~/ 2,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );
  late final Animation<double> _opacity = _curved.drive(
    Tween<double>(begin: ClippoOpacity.disabled, end: 1.0),
  );
  late final Animation<double> _scale = _curved.drive(
    Tween<double>(begin: 0.86, end: 1.14),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ClippoMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Detecção do gesto ligada',
      child: ScaleTransition(
        scale: _scale,
        child: FadeTransition(
          opacity: _opacity,
          child: Container(
            width: ClippoSize.pulseDot,
            height: ClippoSize.pulseDot,
            decoration: const BoxDecoration(color: ClippoBrand.wine, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
