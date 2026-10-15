import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Fundo e margens de toda tela que vem depois da boas-vindas: brilho vinho no topo,
/// conteúdo rolável e, se houver, a pilha de ações presa no rodapé.
class ClippoScreenGround extends StatefulWidget {
  const ClippoScreenGround({
    super.key,
    required this.child,
    this.footer,
    this.enterFromWelcome = false,
  });

  /// Conteúdo do topo (voltar, título, campos…).
  final Widget child;

  /// Ações do rodapé (botão primário + botão de texto ou linha com link).
  /// Fica no fim da tela; se não couber, rola junto com o conteúdo.
  final Widget? footer;

  /// Entrada vinda da boas-vindas: a tela começa coberta de vinho, que se desfaz.
  final bool enterFromWelcome;

  @override
  State<ClippoScreenGround> createState() => _ClippoScreenGroundState();
}

class _ClippoScreenGroundState extends State<ClippoScreenGround> with SingleTickerProviderStateMixin {
  late final AnimationController _wine = AnimationController(
    vsync: this,
    duration: ClippoMotion.enterFromWelcome,
    value: widget.enterFromWelcome ? 1 : 0,
  );
  late final Animation<double> _wineOpacity = CurvedAnimation(parent: _wine, curve: ClippoMotion.standard);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wine.value == 0) return;
    if (ClippoMotion.reduced(context)) {
      _wine.value = 0;
    } else if (!_wine.isAnimating) {
      _wine.reverse();
    }
  }

  @override
  void dispose() {
    _wine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: ClippoSize.glowHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [colors.backgroundGlow, colors.background],
                  ),
                ),
              ),
            ),
            SafeArea(child: _content()),
            AnimatedBuilder(
              animation: _wineOpacity,
              builder: (context, _) {
                if (_wine.value == 0) return const SizedBox.shrink();
                return Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(color: ClippoBrand.wine.withValues(alpha: _wineOpacity.value)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    const padding = EdgeInsets.fromLTRB(
      ClippoSpace.gutter,
      ClippoSpace.sectionL,
      ClippoSpace.gutter,
      ClippoSpace.screenBottom,
    );
    final footer = widget.footer;
    if (footer == null) {
      return SingleChildScrollView(padding: padding, child: widget.child);
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - padding.vertical),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.child,
                const Spacer(),
                const SizedBox(height: ClippoSpace.section),
                footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
