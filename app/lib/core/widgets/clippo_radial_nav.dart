import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';

/// Navegação de nível superior em roda (protótipo v2, adotado em 20/10/2026;
/// ímã, lupa e balão acima do dedo em 09/11/2026).
///
/// Um botão vinho no centro inferior com o ícone da seção atual.
///   • Toque: abre a roda; toque numa seção para ir; toque fora fecha.
///   • Segurar e arrastar (a partir do botão ou de uma seção): as seções reagem
///     ao dedo como um ímã com lupa — crescem conforme ele se aproxima, e a seção
///     acesa é puxada um pouco na direção dele. Tudo vem direto da posição do
///     dedo, sem atraso. Soltar confirma. Soltar perto do botão, ou abaixo dele,
///     cancela.
///   • Enquanto o dedo está em cima do ícone de uma seção, um balão pequeno
///     aparece logo acima dela com o ícone e o nome — como a tecla que aparece
///     no teclado. Saiu do ícone, o balão some.
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

  /// Chave do balão que aparece acima da seção sob o dedo.
  static const Key previewKey = ValueKey('clippoRadialNavPreview');

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

/// De onde veio o dedo que está arrastando: muda o que acontece ao soltar.
enum _DragOrigin { button, item }

class _ClippoRadialNavState extends State<ClippoRadialNav> with TickerProviderStateMixin {
  /// Perto demais do botão, ou abaixo dele: nenhuma seção selecionada.
  static const double _deadZone = 44;

  /// Abaixo do centro do botão, a partir daqui, também cancela.
  static const double _belowCancel = 30;

  /// Andou mais que isso desde que encostou: deixou de ser um toque.
  static const double _tapSlop = 14;

  /// Lupa: quanto uma seção cresce com o dedo em cima dela (+16 %).
  static const double _magnifyMax = 0.16;

  late final AnimationController _wheel = AnimationController(
    vsync: this,
    duration: ClippoMotion.wheelOpen,
    reverseDuration: ClippoMotion.wheelClose,
  );

  /// Força do ímã: 1 enquanto o dedo arrasta (na hora, sem animação); ao soltar,
  /// desce até 0 e as seções voltam ao lugar.
  late final AnimationController _magnet = AnimationController(
    vsync: this,
    duration: ClippoMotion.focus,
  );

  /// Última posição do dedo usada pelo ímã (fica enquanto ele solta).
  Offset? _magnetAt;

  /// Balão acima da seção surgindo (0 → 1) e sumindo.
  late final AnimationController _preview = AnimationController(
    vsync: this,
    duration: ClippoMotion.navPreview,
  );

  late List<Animation<double>> _itemAnimations;

  final GlobalKey _stackKey = GlobalKey();

  bool _open = false;
  bool _dragging = false;
  bool _moved = false;
  _DragOrigin _origin = _DragOrigin.button;
  Offset? _downAt;
  int _highlighted = -1;

  /// Seção com o dedo em cima do ícone (-1: nenhuma). É ela que mostra o balão.
  int _onIcon = -1;

  /// Última seção do balão, para ele sumir sem trocar de conteúdo.
  int _previewIndex = -1;

  /// Centro do botão, calculado no último build.
  Offset _center = Offset.zero;

  bool _reduced = false;

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
    _magnet.dispose();
    _preview.dispose();
    super.dispose();
  }

  // ─── Ímã ──────────────────────────────────────────────────────────────────

  /// Liga o ímã na hora, no dedo em [at].
  void _magnetOn(Offset at) {
    _magnetAt = at;
    _magnet.value = 1;
  }

  /// Solta o ímã: as seções voltam ao tamanho e ao lugar.
  void _magnetOff() {
    if (_reduced) {
      _magnet.value = 0;
    } else {
      _magnet.reverse();
    }
  }

  /// Centro da seção [i] com a roda aberta, sem o ímã.
  Offset _itemTarget(int i) {
    final radians = _angles[i] * math.pi / 180;
    return _center +
        Offset(ClippoSize.navRadius * math.cos(radians), -ClippoSize.navRadius * math.sin(radians));
  }

  /// Ímã + lupa da seção [i], calculados direto da posição do dedo.
  ({double magnify, Offset pull}) _magnetEffect(int i) {
    final at = _magnetAt;
    if (at == null || _magnet.value <= 0) return (magnify: 0, pull: Offset.zero);
    final toFinger = at - _itemTarget(i);
    final distance = toFinger.distance;
    final proximity = (1 - distance / ClippoSize.navMagnetRange).clamp(0.0, 1.0);
    // Curva suave: cresce devagar longe e rápido perto, como o Dock do Mac.
    final magnify = _magnifyMax * Curves.easeOut.transform(proximity) * _magnet.value;
    var pull = Offset.zero;
    if (_highlighted == i && distance > 0) {
      final reach = math.min(distance * 0.25, ClippoSize.navMagnetPull);
      pull = toFinger / distance * reach * _magnet.value;
    }
    return (magnify: magnify, pull: pull);
  }

  /// A seção cujo ícone (já ampliado) está sob o dedo, ou -1.
  int _iconUnder(Offset local) {
    const reach = ClippoSize.navItem / 2 * (1 + _magnifyMax);
    for (var i = 0; i < widget.items.length; i++) {
      if ((local - _itemTarget(i)).distance <= reach) return i;
    }
    return -1;
  }

  void _setOnIcon(int i) {
    if (i == _onIcon) return;
    setState(() {
      _onIcon = i;
      if (i >= 0) _previewIndex = i;
    });
    if (i >= 0) {
      _preview.forward();
    } else {
      _preview.reverse();
    }
  }

  // ─── Abrir, fechar, escolher ──────────────────────────────────────────────

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
      _onIcon = -1;
    });
    _preview.reverse();
    _magnetOff();
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

  // ─── Dedo ─────────────────────────────────────────────────────────────────

  Offset _toLocal(Offset global) {
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    return box == null ? global : box.globalToLocal(global);
  }

  /// Onde o dedo está em relação ao centro do botão → seção mais próxima pelo
  /// ângulo; o ímã acompanha o dedo.
  void _track(Offset global) {
    final local = _toLocal(global);
    if (_downAt != null && (local - _downAt!).distance > _tapSlop) _moved = true;
    if (_moved || _origin == _DragOrigin.item) _magnetOn(local);
    _setOnIcon(_iconUnder(local));

    final dx = local.dx - _center.dx;
    final dy = _center.dy - local.dy; // para cima é positivo
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < _deadZone || dy < -_belowCancel) {
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

  void _startDrag(PointerDownEvent event, _DragOrigin origin) {
    _dragging = true;
    _moved = false;
    _origin = origin;
    _downAt = _toLocal(event.position);
  }

  void _onButtonDown(PointerDownEvent event) {
    if (_open) {
      _close();
      return;
    }
    _openWheel();
    _startDrag(event, _DragOrigin.button);
  }

  void _onItemDown(int i, PointerDownEvent event) {
    if (!_open) return;
    _startDrag(event, _DragOrigin.item);
    _magnetOn(_downAt!);
    _highlight(i);
    _setOnIcon(i);
  }

  void _onMove(PointerMoveEvent event) {
    if (_dragging) _track(event.position);
  }

  void _onUp(PointerUpEvent event) {
    if (!_dragging) return;
    _dragging = false;
    final tapOnButton = _origin == _DragOrigin.button && !_moved;
    if (_highlighted >= 0 && !tapOnButton) {
      _select(_highlighted);
      return;
    }
    if (_origin == _DragOrigin.button && _moved) {
      _close();
      return;
    }
    // Foi um toque no botão, ou o dedo saiu da seção e voltou ao centro:
    // a roda fica aberta, esperando a escolha.
    setState(() {
      _highlighted = -1;
      _onIcon = -1;
    });
    _preview.reverse();
    _magnetOff();
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_dragging) return;
    _dragging = false;
    if (_origin == _DragOrigin.button && _moved) {
      _close();
      return;
    }
    setState(() {
      _highlighted = -1;
      _onIcon = -1;
    });
    _preview.reverse();
    _magnetOff();
  }

  // ─── Desenho ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    _reduced = ClippoMotion.reduced(context);
    if (_reduced) {
      _wheel.duration = ClippoMotion.focus;
      _preview.duration = Duration.zero;
    } else {
      _wheel.duration = ClippoMotion.wheelOpen;
      _preview.duration = ClippoMotion.navPreview;
    }
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _open) _close();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          _center = Offset(
            box.maxWidth / 2,
            box.maxHeight - safeBottom - ClippoSize.navBottom - ClippoSize.navButton / 2,
          );
          final current = widget.items[widget.currentIndex];

          // SizedBox.expand é obrigatório: todos os filhos do Stack são Positioned,
          // então sem ele o Stack se mede como 0×0 — a roda apareceria na tela
          // mas nenhum toque chegaria nela.
          return SizedBox.expand(
            key: _stackKey,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _scrim(colors),
                for (var i = 0; i < widget.items.length; i++) _item(i, _center, colors),
                _button(_center, current, colors),
                _previewBubble(box.maxWidth),
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

  Widget _item(int i, Offset center, ClippoColors colors) {
    final target = _itemTarget(i);
    final item = widget.items[i];
    final isHighlighted = _highlighted == i;
    final isCurrent = widget.currentIndex == i;
    final iconColor = isHighlighted
        ? ClippoBrand.onWine
        : (isCurrent ? colors.accent : colors.text);

    return AnimatedBuilder(
      animation: Listenable.merge([_itemAnimations[i], _magnet]),
      builder: (context, child) {
        final t = _itemAnimations[i].value; // passa de 1 no impulso da mola
        final position = Offset.lerp(center, target, t)!;

        // Ímã + lupa: calculados direto da posição do dedo, a cada quadro.
        final effect = _magnetEffect(i);
        final pull = effect.pull;
        final scale = (0.4 + 0.6 * t) * (1 + effect.magnify);
        return Positioned(
          key: ClippoRadialNav.itemKey(i),
          left: position.dx - ClippoSize.navItem / 2,
          top: position.dy - ClippoSize.navItem / 2,
          child: IgnorePointer(
            ignoring: !_open,
            child: Opacity(
              opacity: t.clamp(0, 1).toDouble(),
              child: Transform.translate(
                offset: pull,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          ),
        );
      },
      child: Semantics(
        button: true,
        selected: isCurrent,
        label: isCurrent ? '${item.label}, seção atual' : item.label,
        onTap: () => _select(i),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _onItemDown(i, event),
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
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

  /// O balão logo acima da seção sob o dedo, como a tecla do teclado: ícone e
  /// nome. Fica preso à seção (acompanha só a lupa e o ímã dela) e não sai da tela.
  Widget _previewBubble(double width) {
    final index = _previewIndex;
    if (index < 0 || index >= widget.items.length) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }
    final item = widget.items[index];
    const w = ClippoSize.navPreviewWidth;
    const h = ClippoSize.navPreviewHeight;

    return AnimatedBuilder(
      animation: Listenable.merge([_magnet, _preview]),
      builder: (context, child) {
        final effect = _magnetEffect(index);
        final at = _itemTarget(index) + effect.pull;
        final itemTop = at.dy - ClippoSize.navItem / 2 * (1 + effect.magnify);
        return Positioned(
          key: ClippoRadialNav.previewKey,
          left: (at.dx - w / 2).clamp(ClippoSpace.spaceM, width - w - ClippoSpace.spaceM),
          top: itemTop - ClippoSpace.spaceS - h,
          child: child!,
        );
      },
      child: IgnorePointer(
        child: ScaleTransition(
          scale: CurvedAnimation(parent: _preview, curve: ClippoMotion.pop),
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _preview,
            child: Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                color: ClippoBrand.wine,
                borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClippoSvgIcon(item.icon, color: ClippoBrand.onWine),
                  const SizedBox(height: ClippoSpace.spaceXs),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
                  ),
                ],
              ),
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
          onPointerDown: _onButtonDown,
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
