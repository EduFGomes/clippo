import 'package:flutter/material.dart';

import 'package:clippo/dev/component_gallery.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';
import 'package:clippo/features/friends/screens/friends_screen.dart';
import 'package:clippo/features/home/screens/home_screen.dart';
import 'package:clippo/features/home/screens/player_screen.dart';
import 'package:clippo/features/home/screens/session_screen.dart';
import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/features/onboarding/screens/complete_profile_screen.dart';
import 'package:clippo/features/onboarding/screens/how_it_works_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';
import 'package:clippo/features/onboarding/screens/welcome_screen.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';

/// PROVISÓRIO: abre cada tela isoladamente enquanto a navegação definitiva
/// não existe. Apague esta pasta (lib/dev/) quando a navegação estiver pronta.
///
/// Criou uma tela nova? Adicione uma linha em [_entries]. Componente novo vai na [ComponentGallery].
class ScreenCatalog extends StatelessWidget {
  const ScreenCatalog({super.key});

  static final List<_Entry> _entries = [
    _Entry('Componentes', 'core/widgets', (_) => const ComponentGallery()),
    _Entry('Boas-vindas', 'onboarding', (_) => const WelcomeScreen()),
    _Entry('Como funciona', 'onboarding', (_) => const HowItWorksScreen()),
    _Entry('Entrar', 'onboarding', (_) => const SignInScreen()),
    _Entry('Criar conta', 'onboarding', (_) => const SignUpScreen()),
    _Entry('Complete seu perfil', 'onboarding', (_) => const CompleteProfileScreen()),
    _Entry('Início', 'home', (_) => const HomeScreen()),
    _Entry('Sessão', 'home', (_) => const SessionScreen()),
    _Entry('Player', 'home', (_) => const PlayerScreen()),
    _Entry('Gravar', 'capture', (_) => const CaptureScreen()),
    _Entry('Amigos', 'friends', (_) => const FriendsScreen()),
    _Entry('Perfil', 'profile', (_) => const ProfileScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clippo · catálogo de telas'),
        actions: [
          TextButton(onPressed: () => authRepository.signOut(), child: const Text('Sair')),
        ],
      ),
      body: ListView(
        children: [
          for (final entry in _entries)
            ListTile(
              title: Text(entry.title),
              subtitle: Text(entry.feature.startsWith('core/') ? entry.feature : 'features/${entry.feature}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: entry.builder),
              ),
            ),
        ],
      ),
    );
  }
}

class _Entry {
  const _Entry(this.title, this.feature, this.builder);

  final String title;
  final String feature;
  final WidgetBuilder builder;
}
