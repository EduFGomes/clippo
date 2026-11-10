import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';

/// Linha de configuração clicável no perfil (ex.: "Nome ›", "Usuário ›").
class ProfileActionTile extends StatefulWidget {
  const ProfileActionTile({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  State<ProfileActionTile> createState() => _ProfileActionTileState();
}

class _ProfileActionTileState extends State<ProfileActionTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      button: true,
      label: '${widget.label}: ${widget.value}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedContainer(
          duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus,
          curve: ClippoMotion.standard,
          constraints: const BoxConstraints(minHeight: ClippoSize.buttonHeight),
          padding: const EdgeInsetsDirectional.fromSTEB(
            ClippoSpace.spaceL,
            ClippoSpace.fieldPaddingV,
            ClippoSpace.fieldPaddingEndWithAction,
            ClippoSpace.fieldPaddingV,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            border: Border.all(
              color: _pressed ? colors.accent : colors.surface,
              width: ClippoSize.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: ClippoText.label.copyWith(color: colors.textLabel)),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(widget.value, style: ClippoText.input.copyWith(color: colors.text)),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: ClippoSize.minTouchTarget,
                child: Center(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: ClippoIcon(
                      ClippoIconShape.chevronLeft,
                      size: ClippoSize.fieldIcon,
                      color: colors.textLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de configuração com chave liga/desliga no perfil (ex.: "Notificações").
class ProfileToggleTile extends StatelessWidget {
  const ProfileToggleTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final duration = ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus;

    return Semantics(
      button: true,
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Container(
          constraints: const BoxConstraints(minHeight: ClippoSize.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: ClippoSpace.spaceL,
            vertical: ClippoSpace.fieldPaddingV,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: ClippoText.input.copyWith(color: colors.text)),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              AnimatedContainer(
                duration: duration,
                curve: ClippoMotion.standard,
                width: ClippoSize.buttonHeight,
                height: ClippoSize.step,
                padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceXs),
                decoration: BoxDecoration(
                  color: value ? colors.accent : colors.controlSoft,
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  border: Border.all(
                    color: value ? colors.accent : colors.outline,
                    width: ClippoSize.border,
                  ),
                ),
                child: AnimatedAlign(
                  duration: duration,
                  curve: ClippoMotion.standard,
                  alignment: value
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  child: Container(
                    width: ClippoSize.check,
                    height: ClippoSize.check,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? colors.onPrimary : colors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
