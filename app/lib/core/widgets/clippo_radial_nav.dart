import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Navegação de nível superior em roda (protótipo v2, adotado em 20/10/2026).
///
/// Um botão vinho no centro inferior com o ícone da seção atual.
///   • Toque: abre a roda; toque numa seção para ir; toque fora fecha.
///   • Segurar e arrastar: a seção sob o dedo acende (a fatia inteira) e soltar
///     confirma. Soltar perto do botão, ou abaixo dele, cancela.
///   • "Voltar" do Android fecha a roda.
///
/// Fica por cima do conteúdo, no mesmo Stack. A tela embaixo precisa terminar com
/// [ClippoSize.navClearance] de folga para a roda não cobrir o fim da lista.
class ClippoRadialNav extends StatefulWidget {
  const ClippoRadialNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelected,
  });

  final List<ClippoRadialNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  /// Chave do botão que abre a roda.
  static const Key buttonKey = ValueKey('clippoRadialNavButton');

  /// Chave da seção na posição [index] da roda.
  static Key itemKey(int index) => ValueKey('clippoRadialNavItem$index');

  @override
  State<ClippoRadialNav> createState() => _ClippoRadialNavState();
}

/// Uma seção da roda. O ícone é um SVG de assets/icons/ (só o nome, sem pasta
/// nem extensão: "home", "capture", "friends", "profile").
class ClippoRadialNavItem {
  const ClippoRadialNavItem({required this.label, required this.icon});

  final String label;
  final String icon;
}

class _ClippoRadialNavState extends State<ClippoRadialNav> with SingleTickerProviderStateMixin {
  /// Perto demais do botão, ou abaixo dele: nenhuma seção selecionada.
  static const double _deadZone = 44;

  /// Meia-abertura da fatia acesa, em graus.
  static const double _wedgeHalf = 26;

  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: ClippoMotion.wheelOpen,
    reverseDuration: ClippoMotion.wheelClose,
  );
  late List<Animation<double>> _itemAnimations;

  bool _open = false;
  bool _dragging = false;
  bool _moved = false;
  int _highlighted = -1;

  /// Ângulos em graus (0 = direita, 90 = em cima), espalhados num arco de 144°.
  List<double> get _angles {
    final n = widget.items.length;
    if (n == 1) return const [90];
    return List.generate(n, (i) => 162 - i * (144 / (n - 1)));
  }

  @override
  void initState() {
    super.initState();
    _buildItemAnimations();
  }

  @override
  void didUpdateWidget(ClippoRadialNav old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _buildItemAnimations();
  }

  void _buildItemAnimations() {
    _itemAnimations = List.generate(widget.items.length, (i) {
      final start = i * 0.08; // cascata de ~30 ms entre as seções
      return CurvedAnimation(
        parent: _wheel,
        curve: Interval(start, math.min(1, 0.62 + start), curve: ClippoMotion.pop),
        reverseCurve: Curves.easeIn,
      );
    });
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  void _openWheel() {
    HapticFeedback.lightImpact();
    setState(() {
      _open = true;
      _highlighted = -1;
    });
    _wheel.forward();
  }

  void _close() {
    setState(() {
      _open = false;
      _dragging = false;
      _highlighted = -1;
    });
    _wheel.reverse();
  }

  void _select(int i) {
    HapticFeedback.mediumImpact();
    _close();
    if (i != widget.currentIndex) widget.onSelected(i);
  }

  void _highlight(int i) {
    if (i == _highlighted) return;
    if (i >= 0) HapticFeedback.selectionClick();
    setState(() => _highlighted = i);
  }

  /// Onde o dedo está em relação ao centro do botão → seção mais próxima pelo ângulo.
  void _track(Offset local) {
    const half = ClippoSize.navButton / 2 + ClippoSize.navRing;
    final dx = local.dx - half;
    final dy = half - local.dy; // para cima é positivo
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance > 14) _moved = true;
    if (distance < _deadZone || dy < -30) {
      _highlight(-1);
      return;
    }
    final angle = math.atan2(math.max(dy, 0), dx) * 180 / math.pi;
    final angles = _angles;
    var best = 0;
    var bestDiff = double.infinity;
    for (var i = 0; i < angles.length; i++) {
      final diff = (angles[i] - angle).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    _highlight(best);
  }

  void _onDown(PointerDownEvent event) {
    if (_open) {
      _close();
      return;
    }
    _openWheel();
    _dragging = true;
    _moved = false;
  }

  void _onMove(PointerMoveEvent event) {
    if (_dragging) _track(event.localPosition);
  }

  void _onUp(PointerUpEvent event) {
    if (!_dragging) return;
    _dragging = false;
    if (!_moved) {
      setState(() => _highlighted = -1); // foi um toque: a roda fica aberta
      return;
    }
    if (_highlighted >= 0) {
      _select(_highlighted);
    } else {
      _close();
    }
  }

  void _onCancel(PointerCancelEvent event) {
    if (_dragging && _moved) _close();
    _dragging = false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    if (ClippoMotion.reduced(context)) {
      _wheel.duration = ClippoMotion.focus;
    }
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _open) _close();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final center = Offset(
            box.maxWidth / 2,
            box.maxHeight - safeBottom - ClippoSize.navBottom - ClippoSize.navButton / 2,
          );
          final angles = _angles;
          final current = widget.items[widget.currentIndex];
          final shown = _highlighted >= 0 ? widget.items[_highlighted] : current;

          // SizedBox.expand é obrigatório: todos os filhos do Stack são Positioned,
          // então sem ele o Stack se mede como 0×0 — a roda apareceria na tela
          // mas nenhum toque chegaria nela.
          return SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _scrim(colors),
                _wheelGuide(center, angles, colors),
                _hint(center, shown, colors),
                for (var i = 0; i < widget.items.length; i++) _item(i, center, angles[i], colors),
                _button(center, current, colors),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fundo que cobre a tela quando a roda abre: cor do fundo a 95 %, sem desfoque.
  Widget _scrim(ClippoColors colors) {
    return AnimatedBuilder(
      animation: _wheel,
      builder: (context, _) {
        if (_wheel.value == 0) return const SizedBox.shrink();
        return Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: FadeTransition(
              opacity: _wheel,
              child: ColoredBox(color: colors.background.withAlpha(242)),
            ),
          ),
        );
      },
    );
  }

  Widget _wheelGuide(Offset center, List<double> angles, ClippoColors colors) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _wheel,
          builder: (context, _) => CustomPaint(
            painter: _WheelPainter(
              center: center,
              radius: ClippoSize.navRadius,
              angles: angles,
              highlighted: _highlighted,
              progress: _wheel.value.clamp(0, 1).toDouble(),
              guide: colors.line,
              wedge: colors.accentSoft,
              wedgeHalf: _wedgeHalf,
            ),
          ),
        ),
      ),
    );
  }

  /// Nome da seção e o que fazer, acima do arco.
  Widget _hint(Offset center, ClippoRadialNavItem shown, ClippoColors colors) {
    return Positioned(
      left: 0,
      right: 0,
      top: center.dy - ClippoSize.navRadius - ClippoSize.navItem / 2 - 96,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _wheel,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(shown.label, style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.spaceXs),
              Text(
                _highlighted >= 0
                    ? (_dragging ? 'Solte para abrir' : 'Toque para abrir')
                    : 'Toque ou arraste até uma seção',
                style: ClippoText.label.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int i, Offset center, double angleDeg, ClippoColors colors) {
    final radians = angleDeg * math.pi / 180;
    final target =
        center +
        Offset(ClippoSize.navRadius * math.cos(radians), -ClippoSize.navRadius * math.sin(radians));
    final item = widget.items[i];
    final isHighlighted = _highlighted == i;
    final isCurrent = widget.currentIndex == i;
    final iconColor = isHighlighted
        ? ClippoBrand.onWine
        : (isCurrent ? colors.accent : colors.text);

    return AnimatedBuilder(
      animation: _itemAnimations[i],
      builder: (context, child) {
        final t = _itemAnimations[i].value; // passa de 1 no impulso da mola
        final position = Offset.lerp(center, target, t)!;
        final scale = (0.4 + 0.6 * t) * (isHighlighted ? 1.14 : 1);
        return Positioned(
          key: ClippoRadialNav.itemKey(i),
          left: position.dx - ClippoSize.navItem / 2,
          top: position.dy - ClippoSize.navItem / 2,
          child: IgnorePointer(
            ignoring: !_open,
            child: Opacity(
              opacity: t.clamp(0, 1).toDouble(),
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
            width: ClippoSize.navItem,
            height: ClippoSize.navItem,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: ClippoMotion.focus,
                  curve: ClippoMotion.standard,
                  width: ClippoSize.navItem,
                  height: ClippoSize.navItem,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHighlighted ? ClippoBrand.wine : colors.surface,
                    border: Border.all(color: isHighlighted ? ClippoBrand.wine : colors.line),
                  ),
                  alignment: Alignment.center,
                  child: ClippoSvgIcon(item.icon, color: iconColor),
                ),
                Positioned(
                  top: ClippoSize.navItem + ClippoSpace.spaceXs,
                  left: -24,
                  right: -24,
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(
                      color: isHighlighted ? colors.text : colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _button(Offset center, ClippoRadialNavItem current, ClippoColors colors) {
    const outer = ClippoSize.navButton + ClippoSize.navRing * 2;
    return Positioned(
      key: ClippoRadialNav.buttonKey,
      left: center.dx - outer / 2,
      top: center.dy - outer / 2,
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
            width: outer,
            height: outer,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dragging ? ClippoBrand.wineDeep : ClippoBrand.wine,
              border: Border.all(color: colors.background, width: ClippoSize.navRing),
            ),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _wheel,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_wheel.value.clamp(0, 1).toDouble());
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - t,
                      child: Transform.rotate(
                        angle: t * math.pi / 2,
                        child: ClippoSvgIcon(current.icon, color: ClippoBrand.onWine),
                      ),
                    ),
                    Opacity(
                      opacity: t,
                      child: Transform.rotate(
                        angle: (t - 1) * math.pi / 2,
                        child: const ClippoSvgIcon('close', color: ClippoBrand.onWine),
                      ),
                    ),
                  ],
                );
              },
            ),
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
    required this.highlighted,
    required this.progress,
    required this.guide,
    required this.wedge,
    required this.wedgeHalf,
  });

  final Offset center;
  final double radius;
  final List<double> angles;
  final int highlighted;
  final double progress;
  final Color guide;
  final Color wedge;
  final double wedgeHalf;

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, progress));

    // Fatia acesa: anel em volta da seção sob o dedo.
    if (highlighted >= 0 && highlighted < angles.length) {
      final a = angles[highlighted];
      const inner = 44.0;
      const outer = 162.0;
      canvas.drawPath(
        Path()
          ..arcTo(
            Rect.fromCircle(center: center, radius: outer),
            _rad(-(a + wedgeHalf)),
            _rad(wedgeHalf * 2),
            true,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: inner),
            _rad(-(a - wedgeHalf)),
            _rad(-wedgeHalf * 2),
            false,
          )
          ..close(),
        Paint()..color = wedge,
      );
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
        ..color = guide,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.highlighted != highlighted ||
      old.progress != progress ||
      old.center != center ||
      old.guide != guide;
}
