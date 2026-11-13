import 'dart:async';
import 'package:clippo/core/data/highlight.dart';

/// Repositório em memória para lances favoritos do usuário logado.
class FavoritesRepository {
  FavoritesRepository._();
  static final FavoritesRepository instance = FavoritesRepository._();

  final Set<String> _favoriteIds = <String>{};
  final Map<String, Highlight> _favoriteHighlights = <String, Highlight>{};
  final StreamController<List<Highlight>> _controller = StreamController<List<Highlight>>.broadcast();

  bool isFavorite(String highlightId) => _favoriteIds.contains(highlightId);

  List<Highlight> get favorites => List.unmodifiable(_favoriteHighlights.values);

  Stream<List<Highlight>> watchFavorites() async* {
    yield favorites;
    yield* _controller.stream;
  }

  void toggleFavorite(Highlight highlight) {
    if (_favoriteIds.contains(highlight.id)) {
      _favoriteIds.remove(highlight.id);
      _favoriteHighlights.remove(highlight.id);
    } else {
      _favoriteIds.add(highlight.id);
      _favoriteHighlights[highlight.id] = highlight;
    }
    _controller.add(favorites);
  }
}

final favoritesRepository = FavoritesRepository.instance;
