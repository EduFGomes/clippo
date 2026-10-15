import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Gravação: um fluxo com 4 estados que compartilham câmera, buffer e sessão em andamento (glossário: preparing, recording, saved, finishing).
class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Gravar', docSection: 'produto.md · 4.5 Gravação (estados A a D)');
  }
}
