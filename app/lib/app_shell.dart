import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_radial_nav.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';
import 'package:clippo/features/friends/screens/friends_screen.dart';
import 'package:clippo/features/home/screens/home_screen.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';

/// O app depois do login: as seções de nível superior e a roda de navegação
/// por cima delas (docs/produto.md › Mapa de navegação).
///
/// Este é o único arquivo que conhece todas as features ao mesmo tempo — é o que
/// permite a regra 3 do AGENTS.md (uma feature nunca importa outra). Quando a
/// Início precisa abrir a Gravação, ela avisa aqui.
///
/// Ordem dos destinos: Início · Gravar · Amigos · Perfil (produto.md › 4. Telas).
/// Gravar não é uma aba: abre em tela cheia, sem navegação, e volta para onde estava.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Posição de cada destino na roda.
  static const int _home = 0;
  static const int _record = 1;
  static const int _friends = 2;
  static const int _profile = 3;

  /// Abas que ficam vivas ao mesmo tempo, na ordem do IndexedStack.
  static const List<int> _tabs = [_home, _friends, _profile];

  int _current = _home;

  void _select(int destination) {
    if (destination == _record) {
      _openCapture();
      return;
    }
    setState(() => _current = destination);
  }

  void _openCapture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CaptureScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Stack(
      children: [
        // A roda flutua sobre o conteúdo, então as telas precisam terminar antes
        // dela. Aumentar a área segura resolve sem cada tela saber da navegação.
        MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              bottom: media.padding.bottom + ClippoSize.navClearance,
            ),
          ),
          child: IndexedStack(
            index: _tabs.indexOf(_current),
            children: [
              HomeScreen(onRecord: _openCapture),
              const FriendsScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
        Positioned.fill(
          child: ClippoRadialNav(
            currentIndex: _current,
            onSelected: _select,
            items: const [
              ClippoRadialNavItem(label: 'Início', icon: 'home'),
              ClippoRadialNavItem(label: 'Gravar', icon: 'capture'),
              ClippoRadialNavItem(label: 'Amigos', icon: 'friends'),
              ClippoRadialNavItem(label: 'Perfil', icon: 'profile'),
            ],
          ),
        ),
      ],
    );
  }
}
