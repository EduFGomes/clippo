import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// A ação principal da tela: pílula de largura total no rodapé. Use uma por tela.
class ClippoPrimaryButton extends StatefulWidget {
  const ClippoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  }) : onWine = false;

  /// Variante da boas-vindas, sobre o fundo vinho: pêssego com texto escuro.
  const ClippoPrimaryButton.onWine({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.loading = false,
  }) : onWine = true;

  final String label;
  final VoidCallback? onPressed;

  /// Desabilitado fica a 45 % de opacidade e não responde ao toque.
  final bool enabled;

  /// Mostra que está trabalhando e ignora novos toques.
  final bool loading;
  final bool onWine;

  @override
  State<ClippoPrimaryButton> createState() => _ClippoPrimaryButtonState();
}

class _ClippoPrimaryButtonState extends State<ClippoPrimaryButton> {
  bool _pressed = false;

  bool get _active => widget.enabled && !widget.loading && widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final background = widget.onWine
        ? (_pressed ? ClippoBrand.peachPressed : ClippoBrand.peach)
        : (_pressed ? colors.primaryPressed : colors.primary);
    final foreground = widget.onWine ? ClippoBrand.onPeach : colors.onPrimary;
    final dim = !widget.enabled || widget.onPressed == null;

    return Semantics(
      button: true,
      enabled: _active,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _active ? widget.onPressed : null,
        onTapDown: _active ? (_) => _setPressed(true) : null,
        onTapUp: _active ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        child: AnimatedOpacity(
          opacity: dim ? ClippoOpacity.disabled : 1,
          duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.enable,
          curve: ClippoMotion.standard,
          child: Container(
            constraints: const BoxConstraints(minHeight: ClippoSize.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL, vertical: ClippoSpace.spaceM),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox.square(
                    dimension: ClippoSize.spinner,
                    child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: foreground),
                  )
                : Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: ClippoText.button.copyWith(color: foreground),
                  ),
          ),
        ),
      ),
    );
  }
}
