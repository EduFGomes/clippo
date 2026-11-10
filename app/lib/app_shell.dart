import 'dart:async';

import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_radial_nav.dart';
import 'package:clippo/features/capture/screens/capture_screen.dart';
import 'package:clippo/features/friends/screens/friends_screen.dart';
import 'package:clippo/features/home/screens/home_screen.dart';
import 'package:clippo/features/home/screens/session_screen.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';

/// O app depois do login: as seções de nível superior e a roda de navegação
/// por cima delas (docs/produto.md › Mapa de navegação).
///
/// Este é o único arquivo que conhece todas as features ao mesmo tempo — é o que
/// permite a regra 3 do AGENTS.md (uma feature nunca importa outra). Quando a
/// Início precisa abrir a Gravação ou a aba Amigos abre uma Sessão, ela avisa aqui.
///
/// Ordem dos destinos: Início · Gravar · Amigos · Perfil (produto.md › 4. Telas).
/// Gravar não é uma aba: abre em tela cheia, sem navegação, e volta para onde estava.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.capturePreview});

  /// Permite injetar um preview de câmera nos testes de navegação sem hardware real.
  final WidgetBuilder? capturePreview;

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

  late final List<Session> _localSessions = List<Session>.of(HomeScreen.defaultDemoSessions);
  final StreamController<SessionsSnapshot> _localSessionsController =
      StreamController<SessionsSnapshot>.broadcast();

  Stream<SessionsSnapshot> get _homeSessionsStream async* {
    if (isUserSignedIn) {
      yield* sessionsRepository.watchMySessions();
      return;
    }
    yield SessionsSnapshot(
      sessions: List<Session>.unmodifiable(_localSessions),
      fromCache: false,
    );
    yield* _localSessionsController.stream;
  }

  @override
  void initState() {
    super.initState();
    // Reenvia o que ficou na fila da Gravação (sessões e vídeos sem internet, R13).
    if (isUserSignedIn) uploadQueue.start().catchError((Object _) {});
  }

  @override
  void dispose() {
    _localSessionsController.close();
    super.dispose();
  }

  void _emitLocalSessions() {
    if (!_localSessionsController.isClosed) {
      _localSessionsController.add(
        SessionsSnapshot(
          sessions: List<Session>.unmodifiable(_localSessions),
          fromCache: false,
        ),
      );
    }
  }

  void _select(int destination) {
    if (destination == _record) {
      _openCapture();
      return;
    }
    setState(() => _current = destination);
  }

  void _openCapture() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (captureContext) => CaptureScreen(
          friends: isUserSignedIn ? acceptedFriends(friendsRepository.watchFriendships()) : null,
          preview: widget.capturePreview,
          uploads: isUserSignedIn ? uploadQueue : null,
          onOpenFriends: () {
            Navigator.of(captureContext).pop();
            setState(() => _current = _friends);
          },
          onSessionCreated: (created) {
            setState(() {
              _localSessions.insert(0, created);
              _current = _home;
            });
            _emitLocalSessions();
          },
        ),
      ),
    );
  }

  void _openSessionFromFriends(Session session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SessionScreen(session: session)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      body: Stack(
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
                HomeScreen(
                  sessions: isUserSignedIn ? null : _homeSessionsStream,
                  onRecord: _openCapture,
                ),
                FriendsScreen(onOpenSession: _openSessionFromFriends),
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
      ),
    );
  }
}
