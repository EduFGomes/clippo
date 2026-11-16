import 'package:flutter/material.dart';

import 'package:clippo/core/data/favorite.dart';
import 'package:clippo/core/data/favorites_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_pressable.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/home/widgets/home_feedback.dart';

/// Abre os comentários de um favorito (R19, R22) por baixo do Player.
Future<void> showFavoriteComments(
  BuildContext context, {
  required FavoritePost post,
  required FavoritesRepository repository,
  required String? viewerId,
}) {
  final colors = ClippoColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
    ),
    builder: (_) => FavoriteCommentsSheet(post: post, repository: repository, viewerId: viewerId),
  );
}

/// A lista de comentários e o campo para comentar. O texto é validado aqui, embaixo do campo, e de
/// novo no repositório e no servidor, com as mesmas regras (regra 0 do AGENTS.md).
class FavoriteCommentsSheet extends StatefulWidget {
  const FavoriteCommentsSheet({super.key, required this.post, required this.repository, required this.viewerId});

  final FavoritePost post;
  final FavoritesRepository repository;
  final String? viewerId;

  @override
  State<FavoriteCommentsSheet> createState() => _FavoriteCommentsSheetState();
}

class _FavoriteCommentsSheetState extends State<FavoriteCommentsSheet> {
  late final Stream<List<FavoriteComment>> _comments = widget.repository.watchComments(widget.post.id);
  final TextEditingController _text = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final error = validateComment(_text.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    try {
      await widget.repository.addComment(widget.post.id, _text.text);
      if (mounted) _text.clear();
    } catch (e) {
      final failure = FavoritesFailure.from(e);
      if (mounted) {
        if (failure.code == 'text') {
          setState(() => _error = failure.message);
        } else {
          showHomeMessage(context, failure.message);
        }
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(FavoriteComment comment) async {
    final ok = await confirmHomeAction(
      context,
      title: 'Apagar o comentário?',
      message: 'Ele some para todo mundo.',
      confirmLabel: 'Apagar',
      cancelLabel: 'Manter',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.repository.deleteComment(widget.post.id, comment.id);
    } catch (e) {
      if (mounted) showHomeMessage(context, FavoritesFailure.from(e).message);
    }
  }

  /// R22: o autor apaga o seu; quem favoritou apaga qualquer um.
  bool _canDelete(FavoriteComment c) =>
      widget.viewerId != null && (c.authorId == widget.viewerId || widget.post.ownerId == widget.viewerId);

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ClippoSpace.gutter,
            ClippoSpace.spaceL,
            ClippoSpace.gutter,
            ClippoSpace.spaceL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Comentários', style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.spaceM),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: media.size.height / 2),
                child: StreamBuilder<List<FavoriteComment>>(
                  stream: _comments,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        FavoritesFailure.from(snapshot.error!).message,
                        style: ClippoText.body.copyWith(color: colors.textMuted),
                      );
                    }
                    final comments = snapshot.data;
                    if (comments == null) {
                      return Center(
                        child: SizedBox.square(
                          dimension: ClippoSize.spinner,
                          child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: colors.accent),
                        ),
                      );
                    }
                    if (comments.isEmpty) {
                      return Text(
                        'Ninguém comentou ainda. Comece você.',
                        style: ClippoText.body.copyWith(color: colors.textMuted),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: comments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: ClippoSpace.spaceM),
                      itemBuilder: (context, i) => _CommentRow(
                        comment: comments[i],
                        onDelete: _canDelete(comments[i]) ? () => _delete(comments[i]) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: ClippoSpace.spaceL),
              ClippoTextField(
                label: 'Comentário',
                hint: 'Escreva um comentário',
                controller: _text,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                hasError: _error != null,
                errorText: _error,
              ),
              const SizedBox(height: ClippoSpace.spaceM),
              ClippoPrimaryButton(label: 'Comentar', onPressed: _sending ? null : _send, loading: _sending),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment, this.onDelete});

  final FavoriteComment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final delete = onDelete;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClippoAvatar(name: comment.authorName, photoUrl: comment.authorPhotoUrl, size: ClippoSize.avatar),
        const SizedBox(width: ClippoSpace.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment.authorName, style: ClippoText.label.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.labelToValue),
              Text(comment.text, style: ClippoText.body.copyWith(color: colors.text)),
            ],
          ),
        ),
        if (delete != null)
          Semantics(
            button: true,
            label: 'Apagar comentário',
            child: ExcludeSemantics(
              child: ClippoPressable(
                onTap: delete,
                child: SizedBox.square(
                  dimension: ClippoSize.minTouchTarget,
                  child: Center(child: ClippoSvgIcon('close', size: ClippoSize.checkIcon, color: colors.textMuted)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
