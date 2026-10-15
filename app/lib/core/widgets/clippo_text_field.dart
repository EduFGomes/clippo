import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_icon.dart';

enum _Variant { plain, password, confirmation }

/// Campo de formulário: bloco arredondado com rótulo em cima e valor embaixo.
/// Variantes: [ClippoTextField.password] (com olho) e [ClippoTextField.confirmation] (✓ / "Não bate").
class ClippoTextField extends StatefulWidget {
  const ClippoTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
    this.prefixText,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    this.errorText,
  })  : _variant = _Variant.plain,
        password = null;

  /// Senha com botão de mostrar/ocultar.
  const ClippoTextField.password({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.focusNode,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    this.errorText,
  })  : _variant = _Variant.password,
        password = null,
        keyboardType = TextInputType.visiblePassword,
        textCapitalization = TextCapitalization.none,
        autocorrect = false,
        prefixText = null,
        readOnly = false,
        onTap = null;

  /// Confirmação de senha: mostra ✓ quando bate com [password] e "Não bate" quando não.
  const ClippoTextField.confirmation({
    super.key,
    required this.label,
    required this.controller,
    required TextEditingController this.password,
    this.hint,
    this.focusNode,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.hasError = false,
    this.errorText,
  })  : _variant = _Variant.confirmation,
        keyboardType = TextInputType.visiblePassword,
        autofillHints = null,
        textCapitalization = TextCapitalization.none,
        autocorrect = false,
        prefixText = null,
        readOnly = false,
        onTap = null;

  final String label;
  final String? hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  /// Texto fixo antes do valor (ex.: "@" no nome de usuário).
  final String? prefixText;

  /// Campo que abre outra coisa ao tocar (ex.: seletor de data) em vez do teclado.
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Borda em `error` (ex.: quando a mensagem de erro geral fala deste campo).
  final bool hasError;

  /// Mensagem de erro só deste campo, mostrada logo abaixo. Também liga a borda de erro.
  final String? errorText;

  /// Senha a comparar (só na variante de confirmação).
  final TextEditingController? password;

  final _Variant _variant;

  @override
  State<ClippoTextField> createState() => _ClippoTextFieldState();
}

class _ClippoTextFieldState extends State<ClippoTextField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
    widget.controller.addListener(_refresh);
    widget.password?.addListener(_refresh);
  }

  @override
  void didUpdateWidget(ClippoTextField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_refresh);
      _focus.addListener(_refresh);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (old.password != widget.password) {
      old.password?.removeListener(_refresh);
      widget.password?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    widget.controller.removeListener(_refresh);
    widget.password?.removeListener(_refresh);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _isSecret => widget._variant != _Variant.plain;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final error = widget.hasError || widget.errorText != null;
    final borderColor = error ? colors.error : (_focus.hasFocus ? colors.accent : colors.surface);
    final trailing = _trailing(colors);

    final field = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.readOnly ? widget.onTap : _focus.requestFocus,
      child: AnimatedContainer(
        duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus,
        curve: ClippoMotion.standard,
        padding: EdgeInsetsDirectional.fromSTEB(
          ClippoSpace.spaceL - ClippoSize.border,
          ClippoSpace.fieldPaddingV - ClippoSize.border,
          (trailing == null ? ClippoSpace.spaceL : ClippoSpace.fieldPaddingEndWithAction) - ClippoSize.border,
          ClippoSpace.fieldPaddingV - ClippoSize.border,
        ),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          border: Border.all(color: borderColor, width: ClippoSize.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: ClippoText.label.copyWith(color: colors.textLabel)),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      autofillHints: widget.autofillHints,
                      textCapitalization: widget.textCapitalization,
                      autocorrect: widget.autocorrect,
                      enableSuggestions: !_isSecret,
                      obscureText: _isSecret && _obscured,
                      readOnly: widget.readOnly,
                      showCursor: !widget.readOnly,
                      // Campo só de toque: o bloco inteiro chama onTap uma vez.
                      ignorePointers: widget.readOnly,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      style: ClippoText.input.copyWith(color: colors.text),
                      cursorColor: colors.accent,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: ClippoText.input.copyWith(color: colors.placeholder),
                        prefixText: widget.prefixText,
                        prefixStyle: ClippoText.input.copyWith(color: colors.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );

    if (widget.errorText == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field,
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(ClippoSpace.spaceL, ClippoSpace.spaceS, ClippoSpace.spaceL, 0),
          child: Text(widget.errorText!, style: ClippoText.label.copyWith(color: colors.error)),
        ),
      ],
    );
  }

  Widget? _trailing(ClippoColors colors) {
    switch (widget._variant) {
      case _Variant.plain:
        return null;
      case _Variant.password:
        return Semantics(
          container: true,
          button: true,
          label: _obscured ? 'Mostrar senha' : 'Ocultar senha',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _obscured = !_obscured),
            child: SizedBox.square(
              dimension: ClippoSize.minTouchTarget,
              child: Center(
                child: ClippoIcon(
                  _obscured ? ClippoIconShape.eye : ClippoIconShape.eyeOff,
                  size: ClippoSize.fieldIcon,
                  color: colors.textLabel,
                ),
              ),
            ),
          ),
        );
      case _Variant.confirmation:
        final confirm = widget.controller.text;
        final password = widget.password!.text;
        if (confirm.isEmpty) return null;
        if (confirm == password) {
          return Semantics(
            label: 'A senha confere',
            child: Container(
              width: ClippoSize.check,
              height: ClippoSize.check,
              margin: const EdgeInsetsDirectional.only(end: ClippoSpace.spaceM),
              decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: ClippoIcon(
                ClippoIconShape.check,
                size: ClippoSize.checkIcon,
                color: colors.onPrimary,
                stroke: ClippoSize.checkStroke,
              ),
            ),
          );
        }
        if (confirm.length >= password.length) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: ClippoSpace.spaceM),
            child: Text('Não bate', style: ClippoText.label.copyWith(color: colors.error)),
          );
        }
        return null;
    }
  }
}

