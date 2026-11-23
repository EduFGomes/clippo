import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/favorite.dart';
import 'package:clippo/core/data/favorites_repository.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_highlight_tile.dart';

/// "Favoritos" de um perfil (R18–R20): os lances que a pessoa favoritou, do mais recente para o
/// mais antigo, como cards de lance ([ClippoHighlightTile]) com a data e as contagens de
/// curtidas e comentários. Tocar abre o favorito no Player ([onOpen]).
///
/// Fica em `core/` porque aparece no Perfil, no perfil de um amigo (Amigos) e no de um
/// participante (Sessão). Só funciona para a própria pessoa e os amigos dela (R19): quem chama
/// só mostra a seção para eles.
class ClippoFavoritesSection extends StatefulWidget {
  const ClippoFavoritesSection({
    super.key,
    required this.ownerId,
    required this.onOpen,
    this.emptyText = 'Nenhum favorito ainda.',
    this.posts,
    this.media,
  });

  /// De quem são os favoritos.
  final String ownerId;

  final ValueChanged<FavoritePost> onOpen;

  /// O que aparece sem nenhum favorito.
  final String emptyText;

  /// Fonte dos favoritos. Os testes passam um stream próprio; no app, `favoritesRepository`.
  final Stream<List<FavoritePost>>? posts;

  /// Miniaturas no Storage. No app, `highlightMediaRepository`.
  final HighlightMediaRepository? media;

  @override
  State<ClippoFavoritesSection> createState() => _ClippoFavoritesSectionState();
}

class _ClippoFavoritesSectionState extends State<ClippoFavoritesSection> {
  late final Stream<List<FavoritePost>> _posts = widget.posts ??
      (isUserSignedIn ? favoritesRepository.watchPostsOf(widget.ownerId) : Stream.value(const <FavoritePost>[]));

  HighlightMediaRepository? get _media => widget.media ?? (isUserSignedIn ? highlightMediaRepository : null);

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Favoritos', style: ClippoText.titleS.copyWith(color: colors.text)),
        const SizedBox(height: ClippoSpace.spaceM),
        StreamBuilder<List<FavoritePost>>(
          stream: _posts,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                FavoritesFailure.from(snapshot.error!).message,
                style: ClippoText.body.copyWith(color: colors.textMuted),
              );
            }
            final posts = snapshot.data;
            if (posts == null) {
              return Center(
                child: SizedBox.square(
                  dimension: ClippoSize.spinner,
                  child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: colors.accent),
                ),
              );
            }
            if (posts.isEmpty) {
              return Text(widget.emptyText, style: ClippoText.body.copyWith(color: colors.textMuted));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < posts.length; i++) ...[
                  if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
                  _FavoriteCard(
                    key: ValueKey(posts[i].id),
                    post: posts[i],
                    media: _media,
                    onTap: () => widget.onOpen(posts[i]),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatefulWidget {
  const _FavoriteCard({super.key, required this.post, required this.media, required this.onTap});

  final FavoritePost post;
  final HighlightMediaRepository? media;
  final VoidCallback onTap;

  @override
  State<_FavoriteCard> createState() => _FavoriteCardState();
}

class _FavoriteCardState extends State<_FavoriteCard> {
  File? _thumbnail;

  @override
  void initState() {
    super.initState();
    unawaited(_loadThumbnail());
  }

  Future<void> _loadThumbnail() async {
    final path = widget.post.thumbnailPath;
    final media = widget.media;
    if (path == null || path.isEmpty || media == null) return;
    try {
      final file = await media.thumbnailFile(path);
      if (mounted) setState(() => _thumbnail = file);
    } catch (_) {
      // Sem miniatura (lance antigo) ou sem internet: fica o desenho de quadra.
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final thumbnail = _thumbnail;
    return ClippoHighlightTile(
      title: post.title.isEmpty ? 'Lance' : post.title,
      timing: clippoFavoriteLine(post.playedAt, likes: post.likeCount, comments: post.commentCount),
      thumbnail: thumbnail == null ? null : FileImage(thumbnail),
      onTap: widget.onTap,
    );
  }
}
