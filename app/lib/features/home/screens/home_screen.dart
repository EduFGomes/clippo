import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Início: lista das sessões de que o usuário participa, da mais recente para a mais antiga.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Início', docSection: '03-telas.md · 1. Início');
  }
}
