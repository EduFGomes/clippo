// Clippo — navegação em roda (proposta do protótipo v2).
//
// Um círculo vinho no centro inferior com o ícone da seção atual.
//   • Toque: abre a roda; toque numa seção para ir; toque fora ou no X fecha.
//   • Segurar e arrastar: a roda abre no toque, a seção sob o dedo acende
//     (fatia inteira, como a roda do GTA) e soltar confirma (como o Pinterest).
//     Soltar perto do botão ou abaixo dele cancela.
//   • "Voltar" do Android fecha a roda.
//
// Uso (a roda fica por cima do conteúdo, no mesmo Stack):
//
//   Scaffold(
//     body: Stack(children: [
//       conteudoDaTela,                      // lista termina com 130 dp de folga
//       Positioned.fill(
//         child: ClippoRadialNav(
//           currentIndex: 1,                 // 0 Perfil · 1 Início · 2 Amigos · 3 Gravar
//           items: [
//             RadialNavItem(label: 'Perfil', icon: svgIcon('profile')),
//             RadialNavItem(label: 'Início', icon: svgIcon('home')),
//             RadialNavItem(label: 'Amigos', icon: svgIcon('friends')),
//             RadialNavItem(label: 'Gravar', icon: svgIcon('capture')),
//           ],
//           closeIcon: svgIcon('close'),
//           onSelected: (i) { /* trocar de aba / abrir a gravação */ },
//         ),
//       ),
//     ]),
//   );
//
//   // com flutter_svg, usando os ícones de docs/assets/icons:
//   RadialIconBuilder svgIcon(String name) => (color, size) => SvgPicture.asset(
//         'assets/icons/$name.svg', width: size, height: size,
//         colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
//
// Nota: escrito para Flutter 3.24+ e ainda não compilado. Rode `flutter analyze`.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'clippo_tokens.dart';

typedef RadialIconBuilder = Widget Function(Color color, double size);

class RadialNavItem {
  const RadialNavItem({required this.label, required this.icon});
  final String label;
  final RadialIconBuilder icon;
}

class ClippoRadialNav extends StatefulWidget {
  const ClippoRadialNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
    required this.closeIcon,
  });

  final List<RadialNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;
  final RadialIconBuilder closeIcon;

  @override
  State<ClippoRadialNav> createState() => _ClippoRadialNavState();
}

class _ClippoRadialNavState extends State<ClippoRadialNav> with SingleTickerProviderStateMixin {
  // Medidas (dp) — iguais às do protótipo.
  static const double _fab = 56; // botão fechado (ClippoSize: control-lg)
  static const double _ring = 4; // anel na cor do fundo, no lugar de sombra
  static const double _item = 56;
  static const double _radius = 118; // raio do arco
  static const double _bottom = 28; // do fundo da tela (mais a área segura)
  static const double _deadZone = 44; // perto do botão = nenhuma seleção
  static const double _wedgeHalf = 26; // meia-abertura da fatia, em graus

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late List<Animation<double>> _itemAnims;

  bool _open = false;
  bool _dragging = false;
  bool _moved = false;
  int _hi = -1;

  /// Ângulos (graus, 0 = direita, 90 = em cima) distribuídos num arco de 180°.
  List<double> get _angles {
    final n = widget.items.length;
    if (n == 1) return [90];
    return List.generate(n, (i) => 162 - i * (144 / (n - 1)));
  }

  @override
  void initState() {
    super.initState();
    _buildItemAnims();
  }

  @override
  void didUpdateWidget(ClippoRadialNav old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _buildItemAnims();
  }

  void _buildItemAnims() {
    final n = widget.items.length;
    _itemAnims = List.generate(n, (i) {
      final start = i * 0.08; // cascata de ~30 ms
      return CurvedAnimation(
        parent: _c,
        curve: Interval(start, math.min(1.0, 0.62 + start), curve: ClippoMotion.pop),
        reverseCurve: Curves.easeIn,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // ---------- ações ----------

  void _openWheel() {
    HapticFeedback.lightImpact();
    setState(() {
      _open = true;
      _hi = -1;
    });
    _c.forward();
  }

  void _close() {
    setState(() {
      _open = false;
      _dragging = false;
      _hi = -1;
    });
    _c.reverse();
  }

  void _select(int i) {
    HapticFeedback.mediumImpact();
    _close();
    if (i != widget.currentIndex) widget.onSelected(i);
  }

  void _setHi(int i) {
    if (i == _hi) return;
    if (i >= 0) HapticFeedback.selectionClick();
    setState(() => _hi = i);
  }

  /// Posição do dedo relativa ao centro do botão → seção mais próxima pelo ângulo.
  void _track(Offset local) {
    const half = _fab / 2 + _ring;
    final dx = local.dx - half;
    final dy = half - local.dy; // para cima é positivo
    final d = math.sqrt(dx * dx + dy * dy);
    if (d > 14) _moved = true;
    if (d < _deadZone || dy < -30) {
      _setHi(-1);
      return;
    }
    final a = math.atan2(math.max(dy, 0.0), dx) * 180 / math.pi;
    final angles = _angles;
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < angles.length; i++) {
      final diff = (angles[i] - a).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    _setHi(best);
  }

  void _onDown(PointerDownEvent e) {
    if (_open) {
      _close();
      return;
    }
    _openWheel();
    _dragging = true;
    _moved = false;
  }

  void _onMove(PointerMoveEvent e) {
    if (_dragging) _track(e.localPosition);
  }

  void _onUp(PointerUpEvent e) {
    if (!_dragging) return;
    _dragging = false;
    if (_moved) {
      if (_hi >= 0) {
        _select(_hi);
      } else {
        _close();
      }
    } else {
      setState(() => _hi = -1); // foi um toque: a roda fica aberta
    }
  }

  void _onCancel(PointerCancelEvent e) {
    if (_dragging && _moved) _close();
    _dragging = false;
  }

  // ---------- desenho ----------

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ClippoColors>()!;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    _c.duration = Duration(milliseconds: reduceMotion ? 150 : 360);
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _open) _close();
      },
      child: LayoutBuilder(builder: (context, box) {
        final center = Offset(box.maxWidth / 2, box.maxHeight - safeBottom - _bottom - _fab / 2);
        final angles = _angles;
        final current = widget.items[widget.currentIndex];
        final shown = _hi >= 0 ? widget.items[_hi] : current;

        return Stack(clipBehavior: Clip.none, children: [
          // Fundo: cor da tela a 95 %, plano (sem desfoque, regra do design system).
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => _c.value == 0
                ? const SizedBox.shrink()
                : Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _close,
                      child: FadeTransition(
                        opacity: _c,
                        child: ColoredBox(color: c.background.withAlpha(242)),
                      ),
                    ),
                  ),
          ),

          // Arco-guia e fatia acesa.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => CustomPaint(
                  painter: _WheelPainter(
                    center: center,
                    radius: _radius,
                    angles: angles,
                    hi: _hi,
                    progress: _c.value.clamp(0.0, 1.0).toDouble(),
                    guideColor: c.divider,
                    wedgeColor: c.accentSoft,
                    wedgeHalf: _wedgeHalf,
                  ),
                ),
              ),
            ),
          ),

          // Nome da seção no centro, acima do arco.
          Positioned(
            left: 0,
            right: 0,
            top: center.dy - _radius - _item / 2 - 96,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _c,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(shown.label, style: ClippoText.cardTitleOpen.copyWith(color: c.text)),
                  const SizedBox(height: 6),
                  Text(
                    _hi >= 0 ? (_dragging ? 'Solte para abrir' : 'Toque para abrir') : 'Toque ou arraste até uma seção',
                    style: ClippoText.meta.copyWith(color: c.textMuted),
                  ),
                ]),
              ),
            ),
          ),

          // Seções.
          for (var i = 0; i < widget.items.length; i++) _positionedItem(i, center, angles[i], c),

          // Botão.
          Positioned(
            left: center.dx - _fab / 2 - _ring,
            top: center.dy - _fab / 2 - _ring,
            child: Semantics(
              button: true,
              expanded: _open,
              label: 'Navegação. Seção atual: ${current.label}',
              onTap: () => _open ? _close() : _openWheel(),
              child: Listener(
                onPointerDown: _onDown,
                onPointerMove: _onMove,
                onPointerUp: _onUp,
                onPointerCancel: _onCancel,
                child: Container(
                  width: _fab + _ring * 2,
                  height: _fab + _ring * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _dragging ? ClippoBrand.wineDeep : ClippoBrand.wine,
                    border: Border.all(color: c.background, width: _ring),
                  ),
                  alignment: Alignment.center,
                  child: AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final t = Curves.easeOut.transform(_c.value.clamp(0.0, 1.0).toDouble());
                      return Stack(alignment: Alignment.center, children: [
                        Opacity(
                          opacity: 1 - t,
                          child: Transform.rotate(angle: t * math.pi / 2, child: current.icon(ClippoBrand.onWine, 24)),
                        ),
                        Opacity(
                          opacity: t,
                          child: Transform.rotate(angle: (t - 1) * math.pi / 2, child: widget.closeIcon(ClippoBrand.onWine, 24)),
                        ),
                      ]);
                    },
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _positionedItem(int i, Offset center, double angleDeg, ClippoColors c) {
    final a = angleDeg * math.pi / 180;
    final target = center + Offset(_radius * math.cos(a), -_radius * math.sin(a));
    final item = widget.items[i];
    final isHi = _hi == i;
    final isCurrent = widget.currentIndex == i;
    final iconColor = isHi ? ClippoBrand.onWine : (isCurrent ? c.accentForeground : c.text);

    return AnimatedBuilder(
      animation: _itemAnims[i],
      builder: (context, child) {
        final t = _itemAnims[i].value; // passa de 1 no impulso da mola
        final pos = Offset.lerp(center, target, t)!;
        final scale = (0.4 + 0.6 * t) * (isHi ? 1.14 : 1.0);
        return Positioned(
          left: pos.dx - _item / 2,
          top: pos.dy - _item / 2,
          child: IgnorePointer(
            ignoring: !_open,
            child: Opacity(
              opacity: t.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
      child: Semantics(
        button: true,
        selected: isCurrent,
        label: isCurrent ? '${item.label}, seção atual' : item.label,
        child: GestureDetector(
          onTap: () => _select(i),
          child: SizedBox(
            width: _item,
            height: _item,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              AnimatedContainer(
                duration: ClippoMotion.fast,
                curve: ClippoMotion.standard,
                width: _item,
                height: _item,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHi ? ClippoBrand.wine : c.surface,
                  border: Border.all(color: isHi ? ClippoBrand.wine : c.divider),
                ),
                alignment: Alignment.center,
                child: item.icon(iconColor, 24),
              ),
              Positioned(
                top: _item + 6,
                left: -24,
                right: -24,
                child: Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: ClippoText.navLabel.copyWith(color: isHi ? c.text : c.textMuted),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.center,
    required this.radius,
    required this.angles,
    required this.hi,
    required this.progress,
    required this.guideColor,
    required this.wedgeColor,
    required this.wedgeHalf,
  });

  final Offset center;
  final double radius;
  final List<double> angles;
  final int hi;
  final double progress;
  final Color guideColor;
  final Color wedgeColor;
  final double wedgeHalf;

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, progress));

    // Fatia acesa (estilo roda do GTA): anel de 44 a 162 dp ao redor da seção.
    if (hi >= 0 && hi < angles.length) {
      final a = angles[hi];
      const inner = 44.0;
      const outer = 162.0;
      final path = Path()
        ..arcTo(Rect.fromCircle(center: center, radius: outer), _rad(-(a + wedgeHalf)), _rad(wedgeHalf * 2), true)
        ..arcTo(Rect.fromCircle(center: center, radius: inner), _rad(-(a - wedgeHalf)), _rad(-wedgeHalf * 2), false)
        ..close();
      canvas.drawPath(path, Paint()..color = wedgeColor);
    }

    // Arco-guia de 180°, fio de 1 dp.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = guideColor,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.hi != hi || old.progress != progress || old.center != center || old.guideColor != guideColor;
}
