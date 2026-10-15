import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Início: lista das sessões de que o usuário participa, da mais recente para a mais antiga.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Início', docSection: 'produto.md · 4.2 Início');
  }
}
