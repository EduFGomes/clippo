import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Perfil: foto, nome, estatísticas e configurações da conta.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Perfil', docSection: 'produto.md · 4.7 Perfil');
  }
}
