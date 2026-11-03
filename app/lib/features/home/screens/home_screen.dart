import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
import 'package:clippo/features/home/screens/session_screen.dart';

/// Início: as sessões de que o usuário participa, da mais recente para a mais
/// antiga (docs/produto.md › 4.2). Só um card fica aberto por vez, e o mais
/// recente já começa aberto.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.sessions, this.profile, this.onRecord});

  /// Fonte das sessões. Os testes passam um stream próprio, sem Firebase;
  /// no app, vem do SessionsRepository (mesmo recurso do `home` em app.dart).
  final Stream<SessionsSnapshot>? sessions;

  /// Perfil de quem está logado, para a saudação e o avatar do topo.
  final Stream<UserProfile?>? profile;

  /// Leva à Gravação, a partir do estado vazio. Vem de fora porque a Início não
  /// pode importar a feature de captura (regra 3 do AGENTS.md): quem liga as duas
  /// é o `AppShell`. Sem ela, o botão aparece desabilitado.
  final VoidCallback? onRecord;

  static final List<Session> defaultDemoSessions = [
    Session(
      id: 'pelada-quinta-11set',
      name: 'Pelada de quinta',
      ownerId: 'gustavo',
      participantIds: const [
        'gustavo',
        'rafa',
        'bruno',
        'alice',
        'caio',
        'diego',
        'leo',
        'pedro',
        'lucas',
        'mateus',
      ],
      participants: const [
        SessionParticipant(uid: 'gustavo', name: 'Gustavo Alves', username: 'gustavo.alves'),
        SessionParticipant(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
        SessionParticipant(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima'),
        SessionParticipant(uid: 'alice', name: 'Alice Prado', username: 'alice.prado'),
        SessionParticipant(uid: 'caio', name: 'Caio Nunes', username: 'caio.nunes'),
      ],
      participantCount: 10,
      startedAt: DateTime(2026, 9, 11, 19, 30),
      endedAt: DateTime(2026, 9, 11, 21, 12),
      duration: const Duration(hours: 1, minutes: 42),
      location: const SessionLocation(label: 'Quadra do Parque'),
      highlightCount: 6,
      isClosed: false,
    ),
    Session(
      id: 'volei-terca-09set',
      name: 'Vôlei de terça',
      ownerId: 'gustavo',
      participantIds: const ['gustavo', 'alice', 'rafa', 'bia'],
      participants: const [
        SessionParticipant(uid: 'gustavo', name: 'Gustavo Alves', username: 'gustavo.alves'),
        SessionParticipant(uid: 'alice', name: 'Alice Prado', username: 'alice.prado'),
        SessionParticipant(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
        SessionParticipant(uid: 'bia', name: 'Bia Ferreira', username: 'bia.ferreira'),
      ],
      participantCount: 8,
      startedAt: DateTime(2026, 9, 9, 20, 0),
      endedAt: DateTime(2026, 9, 9, 21, 45),
      duration: const Duration(hours: 1, minutes: 45),
      location: const SessionLocation(label: 'Ginásio Ibirapuera'),
      highlightCount: 4,
      isClosed: true,
    ),
    Session(
      id: 'beach-sabado-06set',
      name: 'Beach Tennis de sábado',
      ownerId: 'rafa',
      participantIds: const ['rafa', 'gustavo', 'bruno', 'caio'],
      participants: const [
        SessionParticipant(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
        SessionParticipant(uid: 'gustavo', name: 'Gustavo Alves', username: 'gustavo.alves'),
        SessionParticipant(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima'),
        SessionParticipant(uid: 'caio', name: 'Caio Nunes', username: 'caio.nunes'),
      ],
      participantCount: 4,
      startedAt: DateTime(2026, 9, 6, 16, 0),
      endedAt: DateTime(2026, 9, 6, 17, 30),
      duration: const Duration(hours: 1, minutes: 30),
      location: const SessionLocation(label: 'Arena Praia Clube'),
      highlightCount: 5,
      isClosed: false,
    ),
  ];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Stream<SessionsSnapshot> _sessions = _resolveSessions();
  late final Stream<UserProfile?> _profile = _resolveProfile();

  /// Qual card está aberto. Null = nenhum; o primeiro da lista começa aberto.
  String? _openId;
  bool _touchedACard = false;

  Stream<SessionsSnapshot> _resolveSessions() {
    if (widget.sessions != null) return widget.sessions!;
    if (isUserSignedIn) return sessionsRepository.watchMySessions();
    return Stream<SessionsSnapshot>.value(
      SessionsSnapshot(sessions: HomeScreen.defaultDemoSessions, fromCache: false),
    );
  }

  Stream<UserProfile?> _resolveProfile() {
    if (widget.profile != null) return widget.profile!;
    if (isUserSignedIn) return authRepository.watchMyProfile();
    return Stream<UserProfile?>.value(
      const UserProfile(uid: 'gustavo', name: 'Gustavo Alves', username: 'gustavo.alves'),
    );
  }

  void _toggle(Session session) {
    setState(() {
      _touchedACard = true;
      _openId = _openId == session.id ? null : session.id;
    });
  }

  /// Tentar de novo depois de um erro: refaz a consulta.
  void _retry() {
    setState(() => _sessions = _resolveSessions());
  }

  bool _isOpen(Session session, int index) =>
      _touchedACard ? _openId == session.id : index == 0;

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Heading(profile: _profile),
          const SizedBox(height: ClippoSpace.section),
          StreamBuilder<SessionsSnapshot>(
            stream: _sessions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Problem(
                  failure: SessionsFailure.from(snapshot.error!),
                  onRetry: _retry,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();

              final data = snapshot.data;
              if (data == null) return const _Loading();

              // Lista vazia vinda do cache não quer dizer "nunca gravei nada":
              // quer dizer que não deu para falar com o servidor.
              if (data.isEmpty && data.fromCache) {
                return _Problem(
                  failure: const SessionsFailure(
                    'Sem internet. Suas sessões aparecem assim que você conectar.',
                  ),
                  onRetry: _retry,
                );
              }
              if (data.isEmpty) return _Empty(onRecord: widget.onRecord);

              return _List(
                sessions: data.sessions,
                offline: data.fromCache,
                isOpen: _isOpen,
                onToggle: _toggle,
                onOpen: _openSession,
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSession(Session session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SessionScreen(session: session)),
    );
  }
}

/// Saudação, título da tela e o avatar de quem está logado.
class _Heading extends StatelessWidget {
  const _Heading({required this.profile});

  final Stream<UserProfile?> profile;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return StreamBuilder<UserProfile?>(
      stream: profile,
      builder: (context, snapshot) {
        final me = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    clippoGreetingFor(me?.name),
                    style: ClippoText.bodyL.copyWith(color: colors.textMuted),
                  ),
                ),
                const SizedBox(width: ClippoSpace.spaceM),
                ClippoAvatar(
                  name: me?.name ?? '',
                  photoUrl: me?.photoUrl,
                  size: ClippoSize.avatarLarge,
                ),
              ],
            ),
            const SizedBox(height: ClippoSpace.titleToSubtitle),
            const ClippoScreenTitle(line1: 'Suas', line2: 'sessões.'),
          ],
        );
      },
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.sessions,
    required this.offline,
    required this.isOpen,
    required this.onToggle,
    required this.onOpen,
  });

  final List<Session> sessions;

  /// Mostrando o que estava guardado no aparelho: avisa, sem atrapalhar.
  final bool offline;
  final bool Function(Session, int) isOpen;
  final void Function(Session) onToggle;
  final void Function(Session) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (offline) ...[
          Text(
            'Sem internet. Mostrando o que já estava no aparelho.',
            style: ClippoText.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
        ],
        for (var i = 0; i < sessions.length; i++) ...[
          if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
          ClippoSessionCard(
            title: sessions[i].name,
            summary: clippoDotList([
              clippoDate(sessions[i].startedAt),
              clippoHighlightCount(sessions[i].highlightCount),
            ]),
            location: sessions[i].location?.label,
            details: clippoDotList([
              clippoDuration(sessions[i].duration),
              clippoParticipantCount(sessions[i].participantCount),
            ]),
            participants: [
              for (final p in sessions[i].visibleParticipants())
                ClippoAvatarPerson(name: p.name, photoUrl: p.photoUrl),
            ],
            hiddenParticipants: sessions[i].hiddenParticipantCount(),
            expanded: isOpen(sessions[i], i),
            onToggle: () => onToggle(sessions[i]),
            onAction: () => onOpen(sessions[i]),
          ),
        ],
      ],
    );
  }
}

/// Esqueletos no formato do card fechado, enquanto as sessões não chegam.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      label: 'Carregando suas sessões',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            Container(
              height: ClippoSize.skeletonCard,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ninguém gravou nada ainda.
class _Empty extends StatelessWidget {
  const _Empty({this.onRecord});

  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Nenhuma sessão ainda', style: ClippoText.titleS.copyWith(color: colors.text)),
        const SizedBox(height: ClippoSpace.spaceM),
        Text(
          'Posicione o celular, comece a gravar e faça \\ o / quando rolar um lance bom.',
          style: ClippoText.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: ClippoSpace.spaceL),
        ClippoPrimaryButton(
          label: 'Gravar primeira sessão',
          onPressed: onRecord ?? () {},
          enabled: onRecord != null,
        ),
      ],
    );
  }
}

/// Qualquer coisa que impediu de mostrar a lista: sem internet, sessão expirada,
/// erro nosso. A frase vem do repositório, já em português e sem termo técnico.
class _Problem extends StatelessWidget {
  const _Problem({required this.failure, required this.onRetry});

  final SessionsFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(failure.message, style: ClippoText.titleS.copyWith(color: colors.text)),
        const SizedBox(height: ClippoSpace.spaceL),
        ClippoPrimaryButton(label: 'Tentar de novo', onPressed: onRetry),
      ],
    );
  }
}
