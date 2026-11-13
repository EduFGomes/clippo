import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:clippo/core/data/highlight.dart';

/// Repositório para lances favoritos do usuário logado conectado ao Cloud Firestore.
class FavoritesRepository {
  FavoritesRepository._() {
    _initAuthListener();
  }

  static final FavoritesRepository instance = FavoritesRepository._();

  final Set<String> _favoriteIds = <String>{};
  final Map<String, Highlight> _favoriteHighlights = <String, Highlight>{};
  final StreamController<List<Highlight>> _controller = StreamController<List<Highlight>>.broadcast();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSubscription;

  void _initAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _firestoreSubscription?.cancel();
      _favoriteIds.clear();
      _favoriteHighlights.clear();

      if (user == null) {
        _controller.add([]);
        return;
      }

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites');

      _firestoreSubscription = collection.snapshots().listen(
        (snapshot) {
          _favoriteIds.clear();
          _favoriteHighlights.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final highlight = Highlight(
              id: doc.id,
              title: data['title'] as String? ?? 'Destaque',
              offset: Duration(seconds: (data['offsetSeconds'] as num?)?.toInt() ?? 0),
              duration: Duration(seconds: (data['durationSeconds'] as num?)?.toInt() ?? 30),
              savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              createdBy: data['createdBy'] as String? ?? '',
              videoPath: data['videoPath'] as String?,
              thumbnailPath: data['thumbnailPath'] as String?,
            );
            _favoriteIds.add(doc.id);
            _favoriteHighlights[doc.id] = highlight;
          }
          _controller.add(favorites);
        },
        onError: (_) {
          // Mantém o estado atual se offline
        },
      );
    });
  }

  bool isFavorite(String highlightId) => _favoriteIds.contains(highlightId);

  List<Highlight> get favorites => List.unmodifiable(_favoriteHighlights.values);

  Stream<List<Highlight>> watchFavorites() async* {
    yield favorites;
    yield* _controller.stream;
  }

  Future<void> toggleFavorite(Highlight highlight) async {
    final user = FirebaseAuth.instance.currentUser;

    // Atualização otimista imediata na UI
    if (_favoriteIds.contains(highlight.id)) {
      _favoriteIds.remove(highlight.id);
      _favoriteHighlights.remove(highlight.id);
    } else {
      _favoriteIds.add(highlight.id);
      _favoriteHighlights[highlight.id] = highlight;
    }
    _controller.add(favorites);

    // Se estiver logado, persiste no Firestore real
    if (user != null) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(highlight.id);

      if (_favoriteIds.contains(highlight.id)) {
        await docRef.set({
          'highlightId': highlight.id,
          'title': highlight.title,
          'offsetSeconds': highlight.offset.inSeconds,
          'durationSeconds': highlight.duration.inSeconds,
          'savedAt': Timestamp.fromDate(highlight.savedAt),
          'createdBy': highlight.createdBy,
          'videoPath': highlight.videoPath,
          'thumbnailPath': highlight.thumbnailPath,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.delete();
      }
    }
  }
}

final favoritesRepository = FavoritesRepository.instance;
