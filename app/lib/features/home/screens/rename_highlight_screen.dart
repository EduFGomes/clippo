import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_confirm_dialog.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// O que a tela devolve quando o dono apagou o lance (a Sessão avisa "Lance apagado.").
class HighlightDeleted {
  const HighlightDeleted();
}

/// Renomear lance: o dono da sessão troca "Lance 3" por um nome que todos reconhecem, ou
/// apaga o lance para todos.
///
/// Valida no envio (erro embaixo do campo) e o [SessionsRepository] valida de novo antes de
/// chamar a Function `renameHighlight`, que confere tudo outra vez. Devolve o nome gravado
/// (String) ou [HighlightDeleted].
class RenameHighlightScreen extends StatefulWidget {
  const RenameHighlightScreen({
    super.key,
    this.sessionId = 'pelada-quinta-11set',
    this.highlight,
    this.repository,
    this.discardUpload,
  });

  final String sessionId;

  /// O lance. Nulo (catálogo): um lance de exemplo.
  final Highlight? highlight;

  /// No app, `sessionsRepository`.
  final SessionsRepository? repository;

  /// Tira o lance da fila de envio deste aparelho antes de apagar no servidor. No app,
  /// `uploadQueue.discardHighlight` (com alguém logado).
  final Future<void> Function(String sessionId, String highlightId)? discardUpload;

  @override
  State<RenameHighlightScreen> createState() => _RenameHighlightScreenState();
}

class _RenameHighlightScreenState extends State<RenameHighlightScreen> {
  late final Highlight _highlight = widget.highlight ??
      Highlight(
        id: 'lance-0003',
        title: 'Lance 3',
        offset: const Duration(minutes: 27, seconds: 8),
        duration: const Duration(seconds: 30),
        savedAt: DateTime(2026, 9, 11, 19, 57, 8),
        createdBy: 'gustavo',
      );
  late final TextEditingController _title = TextEditingController(text: _highlight.title);

  String? _titleError;
  String? _generalError;
  bool _saving = false;
  bool _deleting = false;

  SessionsRepository get _repository => widget.repository ?? sessionsRepository;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = validateHighlightRename(_title.text);
    setState(() {
      _titleError = error;
      _generalError = null;
    });
    if (error != null) return;

    setState(() => _saving = true);
    try {
      final saved = await _repository.renameHighlight(
        sessionId: widget.sessionId,
        highlightId: _highlight.id,
        title: _title.text,
      );
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      final failure = SessionsFailure.from(e);
      setState(() {
        _saving = false;
        if (failure.code == 'title') {
          _titleError = failure.message;
        } else {
          _generalError = failure.message;
        }
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showClippoConfirm(
      context,
      title: 'Apagar lance?',
      message: '${_highlight.title} some para todos da sessão, com o vídeo. Não dá para desfazer.',
      confirmLabel: 'Apagar lance',
      cancelLabel: 'Manter lance',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _deleting = true;
      _generalError = null;
    });
    try {
      final discard = widget.discardUpload ?? (isUserSignedIn ? uploadQueue.discardHighlight : null);
      await discard?.call(widget.sessionId, _highlight.id);
      await _repository.deleteHighlight(sessionId: widget.sessionId, highlightId: _highlight.id);
      if (mounted) Navigator.of(context).pop(const HighlightDeleted());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _generalError = SessionsFailure.from(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_generalError != null) ...[
            Text(_generalError!, style: ClippoText.label.copyWith(color: colors.error)),
            const SizedBox(height: ClippoSpace.spaceM),
          ],
          ClippoPrimaryButton(label: 'Salvar nome', onPressed: _deleting ? null : _submit, loading: _saving),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: _deleting ? 'Apagando…' : 'Apagar lance',
            onPressed: _saving || _deleting ? null : _delete,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          const ClippoScreenTitle(
            line1: 'Editar',
            line2: 'lance.',
            subtitle: 'Todos da sessão veem o nome novo.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: 'Nome do lance',
            hint: 'Ex.: Voleio do Rafa',
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            errorText: _titleError,
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}
