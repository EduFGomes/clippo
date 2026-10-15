import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Player: reprodução de um highlight.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Player', docSection: 'produto.md · 4.4 Player');
  }
}
