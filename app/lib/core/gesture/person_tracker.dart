/// Segue cada pessoa de um quadro para o outro, para o tempo do gesto ser contado por pessoa.
///
/// O detector não diz quem é quem: a cada quadro ele devolve caixas, em qualquer ordem. Aqui uma
/// caixa recebe o número da pessoa do quadro anterior com quem ela mais se sobrepõe. Simples de
/// propósito: o gesto dura menos de um segundo e, nesse tempo, quem faz \ o / quase não anda.
library;

import 'dart:ui' show Rect;

class PersonTracker {
  PersonTracker({this.minOverlap = 0.3, this.forgetAfter = const Duration(seconds: 1)});

  /// Sobreposição mínima (área em comum ÷ área somada) para duas caixas serem a mesma pessoa.
  final double minOverlap;

  /// Quem some por mais que isso é esquecido; se voltar, ganha um número novo.
  final Duration forgetAfter;

  final Map<int, _Track> _tracks = {};
  int _nextId = 0;

  /// Devolve um número para cada caixa, na mesma ordem. Uma caixa null (pessoa sem posição)
  /// sempre ganha um número novo.
  List<int> assign(Duration timestamp, List<Rect?> boxes) {
    _tracks.removeWhere((_, track) => timestamp - track.lastSeen > forgetAfter);

    // Todos os pares possíveis, do que mais se sobrepõe ao que menos: o par mais parecido fica
    // com o número primeiro.
    final pairs = <(int, int, double)>[
      for (var i = 0; i < boxes.length; i++)
        if (boxes[i] case final box?)
          for (final MapEntry(key: id, value: track) in _tracks.entries)
            if (_overlap(box, track.box) case final overlap when overlap >= minOverlap) (i, id, overlap),
    ]..sort((a, b) => b.$3.compareTo(a.$3));

    final ids = List<int?>.filled(boxes.length, null);
    final taken = <int>{};
    for (final (i, id, _) in pairs) {
      if (ids[i] != null || taken.contains(id)) continue;
      ids[i] = id;
      taken.add(id);
    }
    for (var i = 0; i < boxes.length; i++) {
      final id = ids[i] ??= _nextId++;
      if (boxes[i] case final box?) _tracks[id] = _Track(box, timestamp);
    }
    return ids.cast<int>();
  }

  /// Esquece todo mundo, para uma sessão de gravação nova.
  void reset() {
    _tracks.clear();
    _nextId = 0;
  }

  static double _overlap(Rect a, Rect b) {
    final common = a.intersect(b);
    if (common.width <= 0 || common.height <= 0) return 0;
    final shared = common.width * common.height;
    return shared / (a.width * a.height + b.width * b.height - shared);
  }
}

class _Track {
  const _Track(this.box, this.lastSeen);

  final Rect box;
  final Duration lastSeen;
}
