import 'package:flutter/material.dart';

import 'package:clippo/core/widgets/placeholder_screen.dart';

/// Sessão: highlights de uma sessão em ordem cronológica.
class SessionScreen extends StatelessWidget {
  const SessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(title: 'Sessão', docSection: '03-telas.md · 2. Sessão');
  }
}
