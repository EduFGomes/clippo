import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// Modelo de amigo ou usuário pesquisável na tela Amigos (docs/produto.md › 4.6).
class FriendItem {
  const FriendItem({
    required this.uid,
    required this.name,
    required this.username,
    this.sharedSessions = 0,
    this.totalSessions = 8,
    this.totalHighlights = 19,
    this.totalFriends = 9,
    this.photoUrl,
  });

  final String uid;
  final String name;
  final String username;
  final int sharedSessions;
  final int totalSessions;
  final int totalHighlights;
  final int totalFriends;
  final String? photoUrl;

  String get firstName {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

/// Sessão pesquisável na aba "Sessões" para descobrir ou entrar por busca/código.
///
/// Se [isClosed] for `false` (sessão aberta), qualquer pessoa entra na hora.
/// Se [isClosed] for `true` (sessão fechada), é preciso pedir permissão ao criador.
class DiscoverableSession {
  const DiscoverableSession({
    required this.id,
    required this.code,
    required this.name,
    required this.ownerName,
    required this.locationLabel,
    required this.startedAt,
    required this.duration,
    required this.participantCount,
    required this.highlightCount,
    this.isClosed = false,
    this.joined = false,
    this.joinRequested = false,
  });

  final String id;
  final String code;
  final String name;
  final String ownerName;
  final String locationLabel;
  final DateTime startedAt;
  final Duration duration;
  final int participantCount;
  final int highlightCount;

  /// `false` = sessão aberta (entra direto); `true` = sessão fechada (pede permissão).
  final bool isClosed;
  final bool joined;
  final bool joinRequested;

  DiscoverableSession copyWith({
    int? participantCount,
    bool? isClosed,
    bool? joined,
    bool? joinRequested,
  }) {
    return DiscoverableSession(
      id: id,
      code: code,
      name: name,
      ownerName: ownerName,
      locationLabel: locationLabel,
      startedAt: startedAt,
      duration: duration,
      participantCount: participantCount ?? this.participantCount,
      highlightCount: highlightCount,
      isClosed: isClosed ?? this.isClosed,
      joined: joined ?? this.joined,
      joinRequested: joinRequested ?? this.joinRequested,
    );
  }
}

enum _FriendsTab { friends, sessions }

/// Amigos: busca de amigos e usuários, adição/convite de amigos (R15) e
/// busca/entrada em sessões por nome, local, código ou link (docs/produto.md › 4.6).
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    this.initialFriends,
    this.initialPendingInvites,
    this.directoryUsers,
    this.discoverableSessions,
    this.onOpenSession,
    this.onSessionJoined,
  });

  /// Lista inicial de amigos (permite testar o estado vazio passando `const []`).
  final List<FriendItem>? initialFriends;

  /// Convites de amizade recebidos pendentes de aceite (R15).
  final List<FriendItem>? initialPendingInvites;

  /// Outros usuários do Clippo encontrados ao pesquisar para adicionar amigo.
  final List<FriendItem>? directoryUsers;

  /// Sessões disponíveis para pesquisar e entrar.
  final List<DiscoverableSession>? discoverableSessions;

  /// Abre os detalhes de uma sessão sem importar outra feature (regra 3 do AGENTS.md).
  final ValueChanged<DiscoverableSession>? onOpenSession;

  /// Avisa a casca de navegação quando o usuário entra numa sessão aberta.
  final ValueChanged<DiscoverableSession>? onSessionJoined;

  static const List<FriendItem> _defaultFriends = [
    FriendItem(
      uid: 'rafa',
      name: 'Rafa Costa',
      username: 'rafa.costa',
      sharedSessions: 12,
      totalSessions: 24,
      totalHighlights: 48,
      totalFriends: 14,
    ),
    FriendItem(
      uid: 'bruno',
      name: 'Bruno Lima',
      username: 'bruno.lima',
      sharedSessions: 8,
      totalSessions: 18,
      totalHighlights: 31,
      totalFriends: 11,
    ),
    FriendItem(
      uid: 'alice',
      name: 'Alice Prado',
      username: 'alice.prado',
      sharedSessions: 5,
      totalSessions: 15,
      totalHighlights: 27,
      totalFriends: 13,
    ),
    FriendItem(
      uid: 'caio',
      name: 'Caio Nunes',
      username: 'caio.nunes',
      sharedSessions: 0,
      totalSessions: 6,
      totalHighlights: 11,
      totalFriends: 7,
    ),
  ];

  static const List<FriendItem> _defaultPendingInvites = [
    FriendItem(
      uid: 'diego',
      name: 'Diego Souza',
      username: 'diego.souza',
      sharedSessions: 2,
      totalSessions: 11,
      totalHighlights: 22,
      totalFriends: 9,
    ),
    FriendItem(
      uid: 'leo',
      name: 'Leo Martins',
      username: 'leo.martins',
      sharedSessions: 1,
      totalSessions: 9,
      totalHighlights: 16,
      totalFriends: 8,
    ),
  ];

  static const List<FriendItem> _defaultDirectoryUsers = [
    FriendItem(
      uid: 'pedro',
      name: 'Pedro Rocha',
      username: 'pedro.rocha',
      sharedSessions: 1,
      totalSessions: 10,
      totalHighlights: 19,
      totalFriends: 8,
    ),
    FriendItem(
      uid: 'lucas',
      name: 'Lucas Mendes',
      username: 'lucas.mendes',
      sharedSessions: 0,
      totalSessions: 7,
      totalHighlights: 14,
      totalFriends: 6,
    ),
    FriendItem(
      uid: 'mateus',
      name: 'Mateus Silva',
      username: 'mateus.silva',
      sharedSessions: 0,
      totalSessions: 12,
      totalHighlights: 25,
      totalFriends: 10,
    ),
    FriendItem(
      uid: 'bia',
      name: 'Bia Ferreira',
      username: 'bia.ferreira',
      sharedSessions: 3,
      totalSessions: 14,
      totalHighlights: 29,
      totalFriends: 12,
    ),
  ];

  static final List<DiscoverableSession> _defaultSessions = [
    DiscoverableSession(
      id: 'beach-sabado',
      code: 'BEACH-SAB',
      name: 'Beach Tennis de sábado',
      ownerName: 'Rafa Costa',
      locationLabel: 'Arena Praia Clube',
      startedAt: DateTime(2026, 9, 13, 16, 0),
      duration: const Duration(hours: 1, minutes: 30),
      participantCount: 4,
      highlightCount: 9,
      isClosed: false,
      joined: false,
    ),
    DiscoverableSession(
      id: 'volei-terca',
      code: 'VOLEI-TER',
      name: 'Vôlei de terça',
      ownerName: 'Alice Prado',
      locationLabel: 'Ginásio Ibirapuera',
      startedAt: DateTime(2026, 9, 15, 20, 0),
      duration: const Duration(hours: 1, minutes: 45),
      participantCount: 12,
      highlightCount: 6,
      isClosed: true,
      joined: false,
    ),
    DiscoverableSession(
      id: 'pelada-quinta',
      code: 'PELADA-11SET',
      name: 'Pelada de quinta',
      ownerName: 'Gustavo Alves',
      locationLabel: 'Quadra do Parque',
      startedAt: DateTime(2026, 9, 11, 19, 30),
      duration: const Duration(hours: 1, minutes: 42),
      participantCount: 10,
      highlightCount: 7,
      isClosed: false,
      joined: true,
    ),
  ];

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  _FriendsTab _tab = _FriendsTab.friends;

  final _friendSearchController = TextEditingController();
  final _sessionSearchController = TextEditingController();
  final _sessionCodeController = TextEditingController();

  late List<FriendItem> _friends =
      List<FriendItem>.from(widget.initialFriends ?? FriendsScreen._defaultFriends);
  late final List<FriendItem> _pendingInvites =
      List<FriendItem>.from(widget.initialPendingInvites ?? FriendsScreen._defaultPendingInvites);
  late final List<FriendItem> _directoryUsers =
      List<FriendItem>.from(widget.directoryUsers ?? FriendsScreen._defaultDirectoryUsers);
  late List<DiscoverableSession> _sessions =
      List<DiscoverableSession>.from(widget.discoverableSessions ?? FriendsScreen._defaultSessions);

  final Set<String> _sentRequests = <String>{};
  String? _sessionCodeError;
  String? _sessionJoinFeedback;

  @override
  void dispose() {
    _friendSearchController.dispose();
    _sessionSearchController.dispose();
    _sessionCodeController.dispose();
    super.dispose();
  }

  void _acceptInvite(FriendItem person) {
    setState(() {
      _pendingInvites.removeWhere((item) => item.uid == person.uid);
      if (!_friends.any((f) => f.uid == person.uid)) {
        _friends = [person, ..._friends];
      }
    });
  }

  void _declineInvite(FriendItem person) {
    setState(() {
      _pendingInvites.removeWhere((item) => item.uid == person.uid);
    });
  }

  void _sendFriendRequest(FriendItem person) {
    setState(() {
      _sentRequests.add(person.uid);
    });
  }

  void _removeFriend(FriendItem friend) {
    setState(() {
      _friends.removeWhere((item) => item.uid == friend.uid);
    });
  }

  Future<void> _openInviteScreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const _InviteFriendScreen(),
      ),
    );
  }

  Future<void> _openFriendProfile(FriendItem person, {required bool isFriend}) async {
    final action = await Navigator.of(context).push<_FriendProfileAction>(
      MaterialPageRoute<_FriendProfileAction>(
        builder: (_) => _FriendProfileScreen(
          person: person,
          isFriend: isFriend,
          isRequestSent: _sentRequests.contains(person.uid),
          onOpenSession: widget.onOpenSession,
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _FriendProfileAction.removeFriend) {
      _removeFriend(person);
    } else if (action == _FriendProfileAction.addFriend) {
      _sendFriendRequest(person);
    }
  }

  Future<void> _showFriendOptions(FriendItem friend) async {
    final colors = ClippoColors.of(context);
    final action = await showModalBottomSheet<_FriendMenuOption>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ClippoRadius.radiusField),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ClippoSpace.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  friend.name,
                  style: ClippoText.titleS.copyWith(color: colors.text),
                ),
                const SizedBox(height: ClippoSpace.labelToValue),
                Text(
                  '@${friend.username} · ${clippoSharedSessionsCount(friend.sharedSessions)}',
                  style: ClippoText.label.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: ClippoSpace.spaceL),
                ClippoPrimaryButton(
                  label: 'Ver perfil',
                  onPressed: () => Navigator.of(sheetContext).pop(_FriendMenuOption.viewProfile),
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                ClippoTextButton(
                  label: 'Remover dos amigos',
                  onPressed: () => Navigator.of(sheetContext).pop(_FriendMenuOption.remove),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    if (action == _FriendMenuOption.viewProfile) {
      await _openFriendProfile(friend, isFriend: true);
    } else if (action == _FriendMenuOption.remove) {
      _removeFriend(friend);
    }
  }

  void _joinSession(DiscoverableSession target) {
    DiscoverableSession? joinedSession;
    setState(() {
      if (target.isClosed) {
        _sessions = [
          for (final s in _sessions)
            if (s.id == target.id && !s.joined) s.copyWith(joinRequested: true) else s,
        ];
        _sessionJoinFeedback =
            'Sessão fechada: pedido enviado para ${target.ownerName} liberar sua entrada em ${target.name}.';
      } else {
        _sessions = [
          for (final s in _sessions)
            if (s.id == target.id && !s.joined)
              (joinedSession = s.copyWith(joined: true, participantCount: s.participantCount + 1))
            else
              s,
        ];
        _sessionJoinFeedback = 'Você entrou em ${target.name}.';
      }
    });
    if (joinedSession != null) {
      widget.onSessionJoined?.call(joinedSession!);
    }
  }

  void _joinSessionByCodeOrLink() {
    final raw = _sessionCodeController.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _sessionCodeError = 'Informe o código ou link da sessão.';
        _sessionJoinFeedback = null;
      });
      return;
    }

    // Aceita tanto link ("https://clippo.app/s/pelada-quinta") quanto código curto ("BEACH-SAB").
    final cleaned = raw
        .replaceFirst(RegExp(r'^https?://clippo\.app/s/', caseSensitive: false), '')
        .trim();
    if (cleaned.length < 3 || cleaned.length > 60) {
      setState(() {
        _sessionCodeError = 'Esse código ou link de sessão não parece válido.';
        _sessionJoinFeedback = null;
      });
      return;
    }

    final normalizedQuery = cleaned.toLowerCase();
    final existingIndex = _sessions.indexWhere(
      (s) =>
          s.code.toLowerCase() == normalizedQuery ||
          s.id.toLowerCase() == normalizedQuery ||
          s.name.toLowerCase() == normalizedQuery,
    );

    DiscoverableSession? joinedSession;
    setState(() {
      _sessionCodeError = null;
      _sessionCodeController.clear();
      if (existingIndex >= 0) {
        final found = _sessions[existingIndex];
        if (found.joined) {
          _sessionJoinFeedback = 'Você já participa de ${found.name}.';
        } else if (found.isClosed) {
          _sessions[existingIndex] = found.copyWith(joinRequested: true);
          _sessionJoinFeedback =
              'Sessão fechada: pedido enviado para ${found.ownerName} liberar sua entrada em ${found.name}.';
        } else {
          final updated = found.copyWith(
            joined: true,
            participantCount: found.participantCount + 1,
          );
          _sessions[existingIndex] = updated;
          joinedSession = updated;
          _sessionJoinFeedback = 'Você entrou em ${found.name}.';
        }
      } else {
        final created = DiscoverableSession(
          id: cleaned.toLowerCase(),
          code: cleaned.toUpperCase(),
          name: 'Sessão $cleaned',
          ownerName: 'Convidado via link',
          locationLabel: 'Quadra compartilhada',
          startedAt: DateTime(2026, 9, 16, 19, 0),
          duration: const Duration(hours: 1, minutes: 20),
          participantCount: 6,
          highlightCount: 4,
          isClosed: false,
          joined: true,
        );
        _sessions = [created, ..._sessions];
        joinedSession = created;
        _sessionJoinFeedback = 'Você entrou em ${created.name}.';
      }
    });
    if (joinedSession != null) {
      widget.onSessionJoined?.call(joinedSession!);
    }
  }

  void _openSessionDetails(DiscoverableSession session) {
    widget.onOpenSession?.call(session);
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopHeader(onInvite: _openInviteScreen),
          const SizedBox(height: ClippoSpace.section),
          _ModeTabs(
            selected: _tab,
            onSelected: (next) => setState(() => _tab = next),
          ),
          const SizedBox(height: ClippoSpace.section),
          if (_tab == _FriendsTab.friends)
            _buildFriendsSection()
          else
            _buildSessionsSection(),
        ],
      ),
    );
  }

  Widget _buildFriendsSection() {
    final colors = ClippoColors.of(context);
    final query = _friendSearchController.text.trim().toLowerCase();
    final friendUids = _friends.map((f) => f.uid).toSet();
    final pendingUids = _pendingInvites.map((f) => f.uid).toSet();

    final filteredFriends = query.isEmpty
        ? _friends
        : _friends
            .where(
              (f) =>
                  f.name.toLowerCase().contains(query) ||
                  f.username.toLowerCase().contains(query),
            )
            .toList();

    final discoverablePeople = _directoryUsers
        .where((u) => !friendUids.contains(u.uid) && !pendingUids.contains(u.uid))
        .where(
          (u) =>
              query.isEmpty ||
              u.name.toLowerCase().contains(query) ||
              u.username.toLowerCase().contains(query),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClippoTextField(
          label: 'Buscar amigo ou usuário',
          hint: 'Nome ou @usuário',
          controller: _friendSearchController,
          onChanged: (_) => setState(() {}),
        ),
        if (_pendingInvites.isNotEmpty && query.isEmpty) ...[
          const SizedBox(height: ClippoSpace.section),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Convites pendentes',
                  style: ClippoText.titleS.copyWith(color: colors.text),
                ),
              ),
              Text(
                '${_pendingInvites.length}',
                style: ClippoText.label.copyWith(
                  color: colors.accent,
                  fontFeatures: ClippoText.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          for (var i = 0; i < _pendingInvites.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _PendingInviteTile(
              person: _pendingInvites[i],
              onAccept: () => _acceptInvite(_pendingInvites[i]),
              onDecline: () => _declineInvite(_pendingInvites[i]),
            ),
          ],
        ],
        const SizedBox(height: ClippoSpace.section),
        Row(
          children: [
            Expanded(
              child: Text(
                'Seus amigos',
                style: ClippoText.titleS.copyWith(color: colors.text),
              ),
            ),
            Text(
              '${filteredFriends.length}',
              style: ClippoText.label.copyWith(
                color: colors.textMuted,
                fontFeatures: ClippoText.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        if (_friends.isEmpty && query.isEmpty) ...[
          Text(
            'Adicione quem joga com você',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Text(
            'Quando vocês são amigos, a sessão gravada já aparece na Início de todo mundo.',
            style: ClippoText.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: ClippoSpace.spaceL),
          ClippoPrimaryButton(
            label: 'Convidar amigo',
            onPressed: _openInviteScreen,
          ),
        ] else if (filteredFriends.isEmpty && discoverablePeople.isEmpty) ...[
          Text(
            'Nenhum usuário encontrado para "${_friendSearchController.text.trim()}"',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Text(
            'Confira o @usuário ou envie um convite direto.',
            style: ClippoText.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: ClippoSpace.spaceL),
          ClippoPrimaryButton(
            label: 'Adicionar por @usuário',
            onPressed: _openInviteScreen,
          ),
        ] else ...[
          for (var i = 0; i < filteredFriends.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _FriendRowTile(
              friend: filteredFriends[i],
              onTap: () => _openFriendProfile(filteredFriends[i], isFriend: true),
              onMore: () => _showFriendOptions(filteredFriends[i]),
            ),
          ],
        ],
        if (discoverablePeople.isNotEmpty) ...[
          const SizedBox(height: ClippoSpace.section),
          Text(
            query.isEmpty ? 'Sugestões para adicionar' : 'Mais jogadores no Clippo',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          for (var i = 0; i < discoverablePeople.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _DirectoryUserTile(
              person: discoverablePeople[i],
              sent: _sentRequests.contains(discoverablePeople[i].uid),
              onTap: () => _openFriendProfile(discoverablePeople[i], isFriend: false),
              onAdd: () => _sendFriendRequest(discoverablePeople[i]),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSessionsSection() {
    final colors = ClippoColors.of(context);
    final query = _sessionSearchController.text.trim().toLowerCase();
    final filteredSessions = query.isEmpty
        ? _sessions
        : _sessions
            .where(
              (s) =>
                  s.name.toLowerCase().contains(query) ||
                  s.locationLabel.toLowerCase().contains(query) ||
                  s.ownerName.toLowerCase().contains(query) ||
                  s.code.toLowerCase().contains(query),
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ClippoSpace.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Entrar em uma sessão',
                  style: ClippoText.titleS.copyWith(color: colors.text),
                ),
                const SizedBox(height: ClippoSpace.spaceXs),
                Text(
                  'Cole o link ou digite o código compartilhado por quem criou a partida.',
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: ClippoSpace.spaceM),
                ClippoTextField(
                  label: 'Código ou link da sessão',
                  hint: 'Ex.: BEACH-SAB ou clippo.app/s/...',
                  controller: _sessionCodeController,
                  errorText: _sessionCodeError,
                  onChanged: (_) {
                    if (_sessionCodeError != null) {
                      setState(() => _sessionCodeError = null);
                    }
                  },
                ),
                const SizedBox(height: ClippoSpace.spaceM),
                ClippoPrimaryButton(
                  label: 'Entrar na sessão',
                  onPressed: _joinSessionByCodeOrLink,
                ),
                if (_sessionJoinFeedback != null) ...[
                  const SizedBox(height: ClippoSpace.spaceM),
                  Row(
                    children: [
                      ClippoSvgIcon(
                        'check',
                        size: ClippoSize.checkIcon,
                        color: colors.accent,
                      ),
                      const SizedBox(width: ClippoSpace.spaceS),
                      Expanded(
                        child: Text(
                          _sessionJoinFeedback!,
                          style: ClippoText.label.copyWith(color: colors.accent),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: ClippoSpace.section),
        ClippoTextField(
          label: 'Pesquisar sessão',
          hint: 'Nome da sessão, local ou criador',
          controller: _sessionSearchController,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: ClippoSpace.section),
        Row(
          children: [
            Expanded(
              child: Text(
                'Sessões dos seus amigos',
                style: ClippoText.titleS.copyWith(color: colors.text),
              ),
            ),
            Text(
              '${filteredSessions.length}',
              style: ClippoText.label.copyWith(
                color: colors.textMuted,
                fontFeatures: ClippoText.tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        if (filteredSessions.isEmpty)
          Text(
            'Nenhuma sessão encontrada para "${_sessionSearchController.text.trim()}"',
            style: ClippoText.body.copyWith(color: colors.textMuted),
          )
        else
          for (var i = 0; i < filteredSessions.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _DiscoverSessionCard(
              session: filteredSessions[i],
              onJoin: () => _joinSession(filteredSessions[i]),
              onOpen: () => _openSessionDetails(filteredSessions[i]),
            ),
          ],
      ],
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: ClippoScreenTitle(
            line1: 'Seus',
            line2: 'amigos.',
          ),
        ),
        const SizedBox(width: ClippoSpace.spaceM),
        Semantics(
          button: true,
          label: 'Convidar amigo',
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onInvite,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  border: Border.all(
                    color: colors.accent,
                    width: ClippoSize.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClippoSpace.spaceL,
                    vertical: ClippoSpace.spaceM,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClippoSvgIcon(
                        'plus',
                        size: ClippoSize.checkIcon,
                        color: colors.accent,
                      ),
                      const SizedBox(width: ClippoSpace.spaceS),
                      Text(
                        'Convidar',
                        style: ClippoText.label.copyWith(color: colors.accent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({
    required this.selected,
    required this.onSelected,
  });

  final _FriendsTab selected;
  final ValueChanged<_FriendsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    Widget tabButton(_FriendsTab tab, String label, String icon) {
      final active = selected == tab;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: label,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: ClippoMotion.reduced(context) ? Duration.zero : ClippoMotion.focus,
                curve: ClippoMotion.standard,
                height: ClippoSize.textButtonHeight,
                decoration: BoxDecoration(
                  color: active ? colors.accentSoft : colors.surface,
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  border: Border.all(
                    color: active ? colors.accent : colors.outline,
                    width: ClippoSize.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClippoSvgIcon(
                      icon,
                      size: ClippoSize.checkIcon,
                      color: active ? colors.accent : colors.textMuted,
                    ),
                    const SizedBox(width: ClippoSpace.spaceS),
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: ClippoText.label.copyWith(
                          color: active ? colors.accent : colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabButton(_FriendsTab.friends, 'Amigos', 'friends'),
        const SizedBox(width: ClippoSpace.spaceM),
        tabButton(_FriendsTab.sessions, 'Sessões', 'search'),
      ],
    );
  }
}

class _PendingInviteTile extends StatelessWidget {
  const _PendingInviteTile({
    required this.person,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendItem person;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(
          color: colors.outline,
          width: ClippoSize.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.cardPadding),
        child: Row(
          children: [
            ClippoAvatar(
              name: person.name,
              photoUrl: person.photoUrl,
              size: ClippoSize.avatarLarge,
            ),
            const SizedBox(width: ClippoSpace.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    '@${person.username} · quer jogar com você',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceS),
            Semantics(
              button: true,
              label: 'Recusar convite de ${person.name}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDecline,
                  child: Container(
                    width: ClippoSize.step,
                    height: ClippoSize.step,
                    decoration: BoxDecoration(
                      color: colors.controlSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: ClippoSvgIcon(
                      'close',
                      size: ClippoSize.checkIcon,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceS),
            Semantics(
              button: true,
              label: 'Aceitar convite de ${person.name}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAccept,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ClippoSpace.spaceM,
                        vertical: ClippoSpace.spaceS,
                      ),
                      child: Text(
                        'Aceitar',
                        style: ClippoText.label.copyWith(color: colors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRowTile extends StatelessWidget {
  const _FriendRowTile({
    required this.friend,
    required this.onTap,
    required this.onMore,
  });

  final FriendItem friend;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final secondary = clippoDotList([
      '@${friend.username}',
      clippoSharedSessionsCount(friend.sharedSessions),
    ]);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClippoSpace.cardPadding,
            vertical: ClippoSpace.fieldPaddingV,
          ),
          child: Row(
            children: [
              ClippoAvatar(
                name: friend.name,
                photoUrl: friend.photoUrl,
                size: ClippoSize.avatarLarge,
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClippoText.titleS.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(
                      secondary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClippoText.label.copyWith(
                        color: colors.textMuted,
                        fontFeatures: ClippoText.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Opções de ${friend.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMore,
                  child: SizedBox.square(
                    dimension: ClippoSize.minTouchTarget,
                    child: Center(
                      child: ClippoSvgIcon(
                        'more-vertical',
                        size: ClippoSize.fieldIcon,
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryUserTile extends StatelessWidget {
  const _DirectoryUserTile({
    required this.person,
    required this.sent,
    required this.onTap,
    required this.onAdd,
  });

  final FriendItem person;
  final bool sent;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClippoSpace.cardPadding,
            vertical: ClippoSpace.fieldPaddingV,
          ),
          child: Row(
            children: [
              ClippoAvatar(
                name: person.name,
                photoUrl: person.photoUrl,
                size: ClippoSize.avatarLarge,
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClippoText.titleS.copyWith(color: colors.text),
                    ),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(
                      '@${person.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClippoText.label.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              if (sent)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.controlSoft,
                    borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ClippoSpace.spaceM,
                      vertical: ClippoSpace.spaceS,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClippoSvgIcon(
                          'check',
                          size: ClippoSize.checkIcon,
                          color: colors.accent,
                        ),
                        const SizedBox(width: ClippoSpace.spaceXs),
                        Text(
                          'Enviado',
                          style: ClippoText.label.copyWith(color: colors.accent),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Semantics(
                  button: true,
                  label: 'Adicionar amigo ${person.name}',
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onAdd,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                          border: Border.all(
                            color: colors.accent,
                            width: ClippoSize.border,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ClippoSpace.spaceM,
                            vertical: ClippoSpace.spaceS,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClippoSvgIcon(
                                'plus',
                                size: ClippoSize.checkIcon,
                                color: colors.accent,
                              ),
                              const SizedBox(width: ClippoSpace.spaceXs),
                              Text(
                                'Adicionar',
                                style: ClippoText.label.copyWith(color: colors.accent),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverSessionCard extends StatelessWidget {
  const _DiscoverSessionCard({
    required this.session,
    required this.onJoin,
    required this.onOpen,
  });

  final DiscoverableSession session;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final summary = clippoDotList([
      clippoDate(session.startedAt),
      clippoDuration(session.duration),
      clippoHighlightCount(session.highlightCount),
    ]);
    final details = clippoDotList([
      'Por ${session.ownerName}',
      clippoParticipantCount(session.participantCount),
    ]);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        style: ClippoText.titleS.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: ClippoSpace.labelToValue),
                      Text(
                        summary,
                        style: ClippoText.label.copyWith(
                          color: colors.textMuted,
                          fontFeatures: ClippoText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ClippoSpace.spaceS),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.controlSoft,
                        borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ClippoSpace.spaceM,
                          vertical: ClippoSpace.spaceXs,
                        ),
                        child: Text(
                          session.code,
                          style: ClippoText.label.copyWith(
                            color: colors.accent,
                            fontFeatures: ClippoText.tabular,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: ClippoSpace.spaceXs),
                    Text(
                      session.isClosed ? 'Fechada' : 'Aberta',
                      style: ClippoText.label.copyWith(
                        color: session.isClosed ? colors.textMuted : colors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: ClippoSpace.spaceM),
            Row(
              children: [
                ClippoSvgIcon(
                  'map-pin',
                  size: ClippoSize.checkIcon,
                  color: colors.textMuted,
                ),
                const SizedBox(width: ClippoSpace.spaceS),
                Expanded(
                  child: Text(
                    '${session.locationLabel} · $details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClippoSpace.spaceL),
            if (session.joined)
              Row(
                children: [
                  ClippoSvgIcon(
                    'check',
                    size: ClippoSize.checkIcon,
                    color: colors.accent,
                  ),
                  const SizedBox(width: ClippoSpace.spaceS),
                  Expanded(
                    child: Text(
                      'Participando desta sessão',
                      style: ClippoText.label.copyWith(color: colors.accent),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Ver sessão ${session.name}',
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onOpen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ClippoSpace.spaceM,
                            vertical: ClippoSpace.spaceS,
                          ),
                          child: Text(
                            'Abrir sessão',
                            style: ClippoText.label.copyWith(color: colors.text),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else if (session.joinRequested)
              Row(
                children: [
                  ClippoSvgIcon(
                    'clock',
                    size: ClippoSize.checkIcon,
                    color: colors.accent,
                  ),
                  const SizedBox(width: ClippoSpace.spaceS),
                  Expanded(
                    child: Text(
                      'Aguardando permissão de ${session.ownerName}',
                      style: ClippoText.label.copyWith(color: colors.accent),
                    ),
                  ),
                ],
              )
            else
              ClippoPrimaryButton(
                label: session.isClosed ? 'Pedir para entrar' : 'Entrar na sessão',
                onPressed: onJoin,
              ),
          ],
        ),
      ),
    );
  }
}

enum _FriendMenuOption { viewProfile, remove }

enum _FriendProfileAction { addFriend, removeFriend }

/// Tela "Convidar" do topo: exibe apenas o link simulado para baixar o app Clippo.
class _InviteFriendScreen extends StatefulWidget {
  const _InviteFriendScreen();

  @override
  State<_InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<_InviteFriendScreen> {
  bool _copiedLink = false;

  static const String _downloadAppLink = 'https://clippo.app/baixar';

  Future<void> _copyDownloadLink() async {
    await Clipboard.setData(const ClipboardData(text: _downloadAppLink));
    if (!mounted) return;
    setState(() => _copiedLink = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return ClippoScreenGround(
      footer: ClippoPrimaryButton(
        label: _copiedLink ? 'Link copiado!' : 'Copiar link para baixar o app',
        onPressed: _copyDownloadLink,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(label: 'Amigos'),
          const SizedBox(height: ClippoSpace.section),
          const ClippoScreenTitle(
            line1: 'Convidar',
            line2: 'pro Clippo.',
            subtitle:
                'Mande o link abaixo para quem joga com você baixar o app e participar das sessões.',
          ),
          const SizedBox(height: ClippoSpace.section),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Link para baixar o app (simulado)',
                    style: ClippoText.label.copyWith(color: colors.textLabel),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    _downloadAppLink,
                    style: ClippoText.titleS.copyWith(color: colors.accent),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    'Com o Clippo instalado, a pessoa cria a conta e já aparece na busca para vocês gravarem juntos.',
                    style: ClippoText.body.copyWith(color: colors.textMuted),
                  ),
                  if (_copiedLink) ...[
                    const SizedBox(height: ClippoSpace.spaceM),
                    Row(
                      children: [
                        ClippoSvgIcon(
                          'check',
                          size: ClippoSize.checkIcon,
                          color: colors.accent,
                        ),
                        const SizedBox(width: ClippoSpace.spaceS),
                        Expanded(
                          child: Text(
                            'Link copiado! Agora é só colar na conversa.',
                            style: ClippoText.label.copyWith(color: colors.accent),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Perfil de um amigo ou usuário pesquisado na aba Amigos.
class _FriendProfileScreen extends StatefulWidget {
  const _FriendProfileScreen({
    required this.person,
    required this.isFriend,
    required this.isRequestSent,
    this.onOpenSession,
  });

  final FriendItem person;
  final bool isFriend;
  final bool isRequestSent;
  final ValueChanged<DiscoverableSession>? onOpenSession;

  @override
  State<_FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<_FriendProfileScreen> {
  late bool _requestSent = widget.isRequestSent;
  int? _expandedSessionIndex = 0;

  static final List<DiscoverableSession> _sampleSharedSessions = [
    DiscoverableSession(
      id: 'shared-1',
      code: 'PELADA-11SET',
      name: 'Pelada de quinta',
      ownerName: 'Gustavo Alves',
      locationLabel: 'Quadra do Parque',
      startedAt: DateTime(2026, 9, 11, 19, 30),
      duration: const Duration(hours: 1, minutes: 42),
      participantCount: 10,
      highlightCount: 7,
      joined: true,
    ),
    DiscoverableSession(
      id: 'shared-2',
      code: 'BEACH-SAB',
      name: 'Beach Tennis de sábado',
      ownerName: 'Rafa Costa',
      locationLabel: 'Arena Praia Clube',
      startedAt: DateTime(2026, 9, 6, 16, 0),
      duration: const Duration(hours: 1, minutes: 30),
      participantCount: 4,
      highlightCount: 5,
      joined: true,
    ),
    DiscoverableSession(
      id: 'shared-3',
      code: 'VOLEI-DOM',
      name: 'Vôlei de domingo',
      ownerName: 'Alice Prado',
      locationLabel: 'Ginásio Ibirapuera',
      startedAt: DateTime(2026, 8, 30, 10, 0),
      duration: const Duration(hours: 2),
      participantCount: 12,
      highlightCount: 8,
      joined: true,
    ),
  ];

  List<DiscoverableSession> get _sharedSessions {
    final count = widget.person.sharedSessions;
    if (count <= 0) return const [];
    final limit = count > _sampleSharedSessions.length ? _sampleSharedSessions.length : count;
    return _sampleSharedSessions.sublist(0, limit);
  }

  void _toggleCard(int index) {
    setState(() {
      _expandedSessionIndex = _expandedSessionIndex == index ? null : index;
    });
  }

  void _openSession(DiscoverableSession session) {
    widget.onOpenSession?.call(session);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final person = widget.person;
    final shared = _sharedSessions;

    return ClippoScreenGround(
      footer: widget.isFriend
          ? ClippoTextButton(
              label: 'Remover dos amigos',
              onPressed: () =>
                  Navigator.of(context).pop(_FriendProfileAction.removeFriend),
            )
          : ClippoPrimaryButton(
              label: _requestSent ? 'Convite de amizade enviado' : 'Adicionar amigo',
              onPressed: _requestSent
                  ? null
                  : () {
                      setState(() => _requestSent = true);
                      Navigator.of(context).pop(_FriendProfileAction.addFriend);
                    },
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(label: 'Amigos'),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Perfil de',
            line2: '${person.firstName}.',
            subtitle: clippoSharedSessionsCount(person.sharedSessions),
          ),
          const SizedBox(height: ClippoSpace.section),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                children: [
                  ClippoAvatar(
                    name: person.name,
                    photoUrl: person.photoUrl,
                    size: ClippoSize.avatarProfile,
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    person.name,
                    textAlign: TextAlign.center,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    '@${person.username}',
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: colors.accent),
                  ),
                  if (widget.isFriend) ...[
                    const SizedBox(height: ClippoSpace.spaceM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClippoSvgIcon(
                          'check',
                          size: ClippoSize.checkIcon,
                          color: colors.accent,
                        ),
                        const SizedBox(width: ClippoSpace.spaceXs),
                        Text(
                          'Vocês são amigos',
                          style: ClippoText.label.copyWith(color: colors.accent),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Row(
            children: [
              Expanded(
                child: _FriendStatCard(
                  value: '${person.totalSessions}',
                  label: 'sessões',
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: _FriendStatCard(
                  value: '${person.totalHighlights}',
                  label: 'highlights',
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: _FriendStatCard(
                  value: '${person.totalFriends}',
                  label: 'amigos',
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.section),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sessões juntos',
                  style: ClippoText.titleS.copyWith(color: colors.text),
                ),
              ),
              Text(
                clippoSharedSessionsCount(person.sharedSessions),
                style: ClippoText.label.copyWith(
                  color: colors.textMuted,
                  fontFeatures: ClippoText.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          if (shared.isEmpty)
            Text(
              'Vocês ainda não gravaram nenhuma sessão juntos.',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            )
          else
            for (var i = 0; i < shared.length; i++) ...[
              if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
              ClippoSessionCard(
                title: shared[i].name,
                summary: clippoDotList([
                  clippoDate(shared[i].startedAt),
                  clippoHighlightCount(shared[i].highlightCount),
                ]),
                location: shared[i].locationLabel,
                details: clippoDotList([
                  clippoDuration(shared[i].duration),
                  clippoParticipantCount(shared[i].participantCount),
                ]),
                participants: [
                  ClippoAvatarPerson(name: person.name, photoUrl: person.photoUrl),
                  const ClippoAvatarPerson(name: 'Gustavo Alves'),
                ],
                hiddenParticipants: shared[i].participantCount > 2
                    ? shared[i].participantCount - 2
                    : 0,
                expanded: _expandedSessionIndex == i,
                onToggle: () => _toggleCard(i),
                onAction: () => _openSession(shared[i]),
              ),
            ],
        ],
      ),
    );
  }
}

class _FriendStatCard extends StatelessWidget {
  const _FriendStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: ClippoSpace.fieldPaddingV,
          horizontal: ClippoSpace.spaceM,
        ),
        child: Column(
          children: [
            Text(
              value,
              style: ClippoText.titleS.copyWith(
                color: colors.accent,
                fontFeatures: ClippoText.tabular,
              ),
            ),
            const SizedBox(height: ClippoSpace.labelToValue),
            Text(
              label,
              style: ClippoText.label.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
