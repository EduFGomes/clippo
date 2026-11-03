import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_highlight_tile.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/home/screens/player_screen.dart';

/// Sessão: cabeçalho da sessão, participantes clicáveis, compartilhamento por
/// link/QR Code, edição pelo criador (R12) com controle de sessão aberta/fechada
/// e lista de highlights em ordem cronológica (docs/produto.md › 4.3).
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    this.session,
    this.highlights,
    this.currentUserId,
    this.availableFriends = _defaultFriends,
    this.initialJoinRequests = _defaultJoinRequests,
  });

  /// Sessão aberta. Quando nula (ex.: aberta isoladamente pelo catálogo),
  /// usa uma sessão de exemplo para visualização.
  final Session? session;

  /// Fonte dos highlights. Nos testes ou no catálogo pode vir pronta; no app,
  /// vem de `sessionsRepository.watchHighlightsOf(session.id)`.
  final Stream<HighlightsSnapshot>? highlights;

  /// UID de quem está vendo a sessão. Se nulo, considera o criador da sessão
  /// para permitir testar a edição no catálogo/emulador.
  final String? currentUserId;

  /// Amigos disponíveis para o criador adicionar à sessão (R10, R12).
  final List<SessionParticipant> availableFriends;

  /// Pedidos pendentes para entrar na sessão quando ela é fechada.
  final List<SessionParticipant> initialJoinRequests;

  static const List<SessionParticipant> _defaultFriends = [
    SessionParticipant(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
    SessionParticipant(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima'),
    SessionParticipant(uid: 'alice', name: 'Alice Prado', username: 'alice.prado'),
    SessionParticipant(uid: 'caio', name: 'Caio Nunes', username: 'caio.nunes'),
    SessionParticipant(uid: 'bia', name: 'Bia Ferreira', username: 'bia.ferreira'),
    SessionParticipant(uid: 'gui', name: 'Gui Santos', username: 'gui.santos'),
  ];

  static const List<SessionParticipant> _defaultJoinRequests = [
    SessionParticipant(uid: 'gui', name: 'Gui Santos', username: 'gui.santos'),
  ];

  static final Session _demoSession = Session(
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
      SessionParticipant(uid: 'diego', name: 'Diego Souza', username: 'diego.souza'),
      SessionParticipant(uid: 'leo', name: 'Leo Martins', username: 'leo.martins'),
      SessionParticipant(uid: 'pedro', name: 'Pedro Rocha', username: 'pedro.rocha'),
      SessionParticipant(uid: 'lucas', name: 'Lucas Mendes', username: 'lucas.mendes'),
      SessionParticipant(uid: 'mateus', name: 'Mateus Silva', username: 'mateus.silva'),
    ],
    participantCount: 10,
    startedAt: DateTime(2026, 9, 11, 19, 30),
    endedAt: DateTime(2026, 9, 11, 21, 12),
    duration: const Duration(hours: 1, minutes: 42),
    location: const SessionLocation(label: 'Quadra do Parque'),
    highlightCount: 6,
  );

  static final List<Highlight> _demoHighlights = [
    Highlight(
      id: 'hl-1',
      title: 'Jogada de cinema',
      offset: const Duration(minutes: 4, seconds: 15),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 34, 15),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-2',
      title: 'Ponto antológico',
      offset: const Duration(minutes: 12, seconds: 40),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 42, 40),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-3',
      title: 'Defesa no reflexo',
      offset: const Duration(minutes: 27, seconds: 8),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 57, 8),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-4',
      title: 'Lance na linha',
      offset: const Duration(minutes: 41, seconds: 50),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 20, 11, 50),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-5',
      title: 'Virada de jogo',
      offset: const Duration(minutes: 58, seconds: 12),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 20, 28, 12),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-6',
      title: 'Reflexo absurdo',
      offset: const Duration(hours: 1, minutes: 14, seconds: 22),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 20, 44, 22),
      createdBy: 'gustavo',
      status: HighlightStatus.pending,
    ),
  ];

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late Session _session = widget.session ?? SessionScreen._demoSession;
  late Stream<HighlightsSnapshot> _highlights = _resolveStream();
  late List<SessionParticipant> _joinRequests =
      List<SessionParticipant>.from(widget.initialJoinRequests);
  final Set<String> _sentFriendRequests = <String>{};

  String get _viewerId => widget.currentUserId ?? _session.ownerId;

  bool get _isOwner => _session.isOwnedBy(_viewerId);

  @override
  void didUpdateWidget(covariant SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session && widget.session != null) {
      _session = widget.session!;
    }
    if (widget.highlights != oldWidget.highlights) {
      _highlights = _resolveStream();
    }
  }

  /// Lista completa de participantes para a tela de participantes.
  List<SessionParticipant> get _allParticipants {
    final byId = <String, SessionParticipant>{
      for (final p in widget.availableFriends) p.uid: p,
      for (final p in _session.participants) p.uid: p,
    };
    final result = <SessionParticipant>[];
    for (final p in _session.participants) {
      result.add(p);
    }
    for (final uid in _session.participantIds) {
      if (result.every((p) => p.uid != uid)) {
        result.add(byId[uid] ?? SessionParticipant(uid: uid, name: 'Participante $uid'));
      }
    }
    while (result.length < _session.participantCount) {
      final index = result.length + 1;
      result.add(SessionParticipant(uid: 'p$index', name: 'Jogador $index'));
    }
    return result;
  }

  Stream<HighlightsSnapshot> _resolveStream() {
    if (widget.highlights != null) return widget.highlights!;
    if (widget.session != null && isUserSignedIn) {
      return sessionsRepository.watchHighlightsOf(widget.session!.id);
    }
    return Stream<HighlightsSnapshot>.value(
      HighlightsSnapshot(highlights: SessionScreen._demoHighlights, fromCache: false),
    );
  }

  void _retry() {
    setState(() => _highlights = _resolveStream());
  }

  void _openPlayer(List<Highlight> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          sessionName: _session.name,
          highlights: items,
          initialIndex: index,
        ),
      ),
    );
  }

  Future<void> _openEditSession() async {
    if (!_isOwner) return;
    final result = await Navigator.of(context).push<_EditSessionResult>(
      MaterialPageRoute<_EditSessionResult>(
        builder: (_) => _EditSessionScreen(
          session: _session,
          currentParticipants: _allParticipants,
          availableFriends: widget.availableFriends,
          pendingJoinRequests: _joinRequests,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _session = result.session;
        _joinRequests = result.remainingRequests;
      });
    }
  }

  Future<void> _openParticipants() async {
    final updated = await Navigator.of(context).push<Session>(
      MaterialPageRoute<Session>(
        builder: (_) => _SessionParticipantsScreen(
          session: _session,
          participants: _allParticipants,
          currentUserId: _viewerId,
          isOwner: _isOwner,
          availableFriends: widget.availableFriends,
          sentFriendRequests: _sentFriendRequests,
          pendingJoinRequests: _joinRequests,
          onRemainingJoinRequestsChanged: (remaining) {
            _joinRequests = remaining;
          },
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _session = updated);
    }
  }

  void _openShareSession() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ShareSessionScreen(session: _session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: ClippoBackButton(label: 'Sessões')),
              _HeaderIconButton(
                icon: 'share',
                semanticLabel: 'Compartilhar sessão',
                onPressed: _openShareSession,
              ),
              if (_isOwner) ...[
                const SizedBox(width: ClippoSpace.spaceS),
                _HeaderIconButton(
                  icon: 'edit',
                  semanticLabel: 'Editar sessão',
                  onPressed: _openEditSession,
                ),
              ],
            ],
          ),
          const SizedBox(height: ClippoSpace.section),
          _SessionHeader(
            session: session,
            onTapParticipants: _openParticipants,
          ),
          const SizedBox(height: ClippoSpace.section),
          StreamBuilder<HighlightsSnapshot>(
            stream: _highlights,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Problem(
                  failure: SessionsFailure.from(snapshot.error!),
                  onRetry: _retry,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _Loading(expectedCount: session.highlightCount);
              }

              final data = snapshot.data;
              if (data == null) {
                return _Loading(expectedCount: session.highlightCount);
              }

              if (data.isEmpty && data.fromCache) {
                return _Problem(
                  failure: const SessionsFailure(
                    'Sem internet. Os highlights aparecem assim que você conectar.',
                  ),
                  onRetry: _retry,
                );
              }
              if (data.isEmpty) {
                return const _Empty();
              }

              final distinctHighlights = ensureDistinctHighlightTitles(data.highlights);
              return _HighlightList(
                highlights: distinctHighlights,
                offline: data.fromCache,
                onTapHighlight: (index) => _openPlayer(distinctHighlights, index),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: SizedBox.square(
            dimension: ClippoSize.minTouchTarget,
            child: Center(
              child: Container(
                width: ClippoSize.control,
                height: ClippoSize.control,
                decoration: BoxDecoration(
                  color: colors.controlSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ClippoSvgIcon(
                  icon,
                  size: ClippoSize.fieldIcon,
                  color: colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho da Sessão: título em duas linhas, "data · duração", local,
/// selo de sessão aberta/fechada e participantes clicáveis.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.session,
    required this.onTapParticipants,
  });

  final Session session;
  final VoidCallback onTapParticipants;

  (String, String) _splitTitle(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return ('Sua', 'sessão.');
    final withoutTrailingDot =
        trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1).trim() : trimmed;
    final words = withoutTrailingDot.split(RegExp(r'\s+'));
    if (words.length == 1) {
      return ('Sessão', '${words.first}.');
    }
    final line1 = words.sublist(0, words.length - 1).join(' ');
    final line2 = '${words.last}.';
    return (line1, line2);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final (line1, line2) = _splitTitle(session.name);
    final dateAndDuration = clippoDotList([
      clippoDate(session.startedAt),
      clippoDuration(session.duration),
    ]);
    final place = session.location?.label;
    final visiblePeople = [
      for (final p in session.visibleParticipants())
        ClippoAvatarPerson(name: p.name, photoUrl: p.photoUrl),
    ];
    final hiddenCount = session.hiddenParticipantCount();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClippoScreenTitle(
          line1: line1,
          line2: line2,
          subtitle: dateAndDuration,
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        Wrap(
          spacing: ClippoSpace.spaceM,
          runSpacing: ClippoSpace.spaceS,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (place != null && place.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClippoSvgIcon(
                    'map-pin',
                    size: ClippoSize.checkIcon,
                    color: colors.accent,
                  ),
                  const SizedBox(width: ClippoSpace.spaceS),
                  Flexible(
                    child: Text(
                      place,
                      style: ClippoText.body.copyWith(color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: session.isClosed ? colors.controlSoft : colors.accentSoft,
                borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ClippoSpace.spaceM,
                  vertical: ClippoSpace.spaceXs,
                ),
                child: Text(
                  session.isClosed ? 'Sessão fechada' : 'Sessão aberta',
                  style: ClippoText.label.copyWith(
                    color: session.isClosed ? colors.textMuted : colors.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: ClippoSpace.spaceL),
        Semantics(
          button: true,
          label: 'Ver participantes da sessão (${clippoParticipantCount(session.participantCount)})',
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTapParticipants,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ClippoSpace.cardPadding,
                  vertical: ClippoSpace.fieldPaddingV,
                ),
                child: Row(
                  children: [
                    if (visiblePeople.isNotEmpty || hiddenCount > 0) ...[
                      ClippoAvatarRow(
                        people: visiblePeople,
                        hidden: hiddenCount,
                        ring: colors.surface,
                      ),
                      const SizedBox(width: ClippoSpace.spaceM),
                    ],
                    Expanded(
                      child: Text(
                        clippoParticipantCount(session.participantCount),
                        style: ClippoText.label.copyWith(
                          color: colors.text,
                          fontFeatures: ClippoText.tabular,
                        ),
                      ),
                    ),
                    ClippoSvgIcon(
                      'chevron-right',
                      size: ClippoSize.checkIcon,
                      color: colors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            'Highlights',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
        ),
        const SizedBox(width: ClippoSpace.spaceM),
        Text(
          clippoSavedPlaysCount(count),
          style: ClippoText.label.copyWith(
            color: colors.textMuted,
            fontFeatures: ClippoText.tabular,
          ),
        ),
      ],
    );
  }
}

class _HighlightList extends StatelessWidget {
  const _HighlightList({
    required this.highlights,
    required this.offline,
    required this.onTapHighlight,
  });

  final List<Highlight> highlights;
  final bool offline;
  final ValueChanged<int> onTapHighlight;

  Widget _buildCard(int index) {
    final item = highlights[index];
    return ClippoHighlightTile(
      title: item.title,
      timing: clippoHighlightTiming(
        item.offset,
        item.duration,
        uploading: item.isUploading,
      ),
      uploading: item.isUploading,
      thumbnailUrl: item.thumbnailPath != null && item.thumbnailPath!.startsWith('http')
          ? item.thumbnailPath
          : null,
      onTap: () => onTapHighlight(index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(count: highlights.length),
        const SizedBox(height: ClippoSpace.spaceL),
        if (offline) ...[
          Text(
            'Sem internet. Mostrando o que já estava no aparelho.',
            style: ClippoText.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
        ],
        for (var i = 0; i < highlights.length; i += 2) ...[
          if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildCard(i)),
                const SizedBox(width: ClippoSpace.cardGap),
                Expanded(
                  child: i + 1 < highlights.length
                      ? _buildCard(i + 1)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Esqueletos dos cards em grade 2x2 enquanto os highlights carregam.
class _Loading extends StatelessWidget {
  const _Loading({required this.expectedCount});

  final int expectedCount;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    Widget skeletonBox() => Container(
          height: ClippoSize.thumbnailHeight + ClippoSize.skeletonCard,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(count: expectedCount),
        const SizedBox(height: ClippoSpace.spaceL),
        Semantics(
          label: 'Carregando highlights',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: ClippoSpace.cardGap),
                Row(
                  children: [
                    Expanded(child: skeletonBox()),
                    const SizedBox(width: ClippoSpace.cardGap),
                    Expanded(child: skeletonBox()),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Estado sem highlights salvos na sessão (docs/produto.md › 4.3).
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeading(count: 0),
        const SizedBox(height: ClippoSpace.spaceL),
        Text(
          'Nenhum lance salvo nessa sessão',
          style: ClippoText.titleS.copyWith(color: colors.text),
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        Text(
          'Na próxima vez, olhe para a câmera e faça \\ o / quando rolar um lance bom.',
          style: ClippoText.body.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// Erro ao buscar os highlights da sessão.
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

class _EditSessionResult {
  const _EditSessionResult({
    required this.session,
    required this.remainingRequests,
  });

  final Session session;
  final List<SessionParticipant> remainingRequests;
}

/// Tela de edição da sessão — acessível apenas pelo criador (R12).
class _EditSessionScreen extends StatefulWidget {
  const _EditSessionScreen({
    required this.session,
    required this.currentParticipants,
    required this.availableFriends,
    required this.pendingJoinRequests,
  });

  final Session session;
  final List<SessionParticipant> currentParticipants;
  final List<SessionParticipant> availableFriends;
  final List<SessionParticipant> pendingJoinRequests;

  @override
  State<_EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<_EditSessionScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.session.name);
  late final TextEditingController _locationController =
      TextEditingController(text: widget.session.location?.label ?? '');

  late final List<SessionParticipant> _selectedParticipants =
      List<SessionParticipant>.of(widget.currentParticipants);
  late final List<SessionParticipant> _pendingRequests =
      List<SessionParticipant>.of(widget.pendingJoinRequests);
  late bool _isClosed = widget.session.isClosed;

  String? _nameError;
  String? _locationError;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<SessionParticipant> get _unselectedFriends {
    final pendingUids = _pendingRequests.map((p) => p.uid).toSet();
    return widget.availableFriends
        .where(
          (friend) =>
              _selectedParticipants.every((p) => p.uid != friend.uid) &&
              !pendingUids.contains(friend.uid),
        )
        .toList(growable: false);
  }

  void _removeParticipant(SessionParticipant participant) {
    if (participant.uid == widget.session.ownerId) return;
    setState(() {
      _selectedParticipants.removeWhere((p) => p.uid == participant.uid);
    });
  }

  void _addParticipant(SessionParticipant friend) {
    setState(() {
      _selectedParticipants.add(friend);
    });
  }

  void _approveJoinRequest(SessionParticipant person) {
    setState(() {
      _pendingRequests.removeWhere((p) => p.uid == person.uid);
      if (_selectedParticipants.every((p) => p.uid != person.uid)) {
        _selectedParticipants.add(person);
      }
    });
  }

  void _declineJoinRequest(SessionParticipant person) {
    setState(() {
      _pendingRequests.removeWhere((p) => p.uid == person.uid);
    });
  }

  void _submit() {
    final nameErr = validateSessionName(_nameController.text);
    final locErr = validateLocation(_locationController.text);
    if (nameErr != null || locErr != null) {
      setState(() {
        _nameError = nameErr;
        _locationError = locErr;
      });
      return;
    }

    final normalizedName = normalizeSessionName(_nameController.text);
    final normalizedLoc = normalizeLocation(_locationController.text);

    final updated = widget.session.copyWith(
      name: normalizedName,
      location: normalizedLoc == null ? null : SessionLocation(label: normalizedLoc),
      clearLocation: normalizedLoc == null,
      participantIds: [for (final p in _selectedParticipants) p.uid],
      participants: List<SessionParticipant>.unmodifiable(_selectedParticipants),
      participantCount: _selectedParticipants.length,
      isClosed: _isClosed,
    );

    Navigator.of(context).pop(
      _EditSessionResult(
        session: updated,
        remainingRequests: List<SessionParticipant>.unmodifiable(_pendingRequests),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final unselected = _unselectedFriends;

    return ClippoScreenGround(
      footer: ClippoPrimaryButton(
        label: 'Salvar alterações',
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          const ClippoScreenTitle(
            line1: 'Editar',
            line2: 'sessão.',
            subtitle: 'Como criador, você pode ajustar os dados, o acesso e os participantes.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: 'Nome da sessão',
            hint: 'Ex.: Pelada de quinta',
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Local',
            hint: 'Ex.: Quadra do Parque',
            controller: _locationController,
            textCapitalization: TextCapitalization.words,
            errorText: _locationError,
            onChanged: (_) {
              if (_locationError != null) setState(() => _locationError = null);
            },
          ),
          const SizedBox(height: ClippoSpace.section),
          Text(
            'Acesso à sessão',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Row(
            children: [
              Expanded(
                child: _SessionAccessOptionTile(
                  label: 'Sessão aberta',
                  selected: !_isClosed,
                  onTap: () => setState(() => _isClosed = false),
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: _SessionAccessOptionTile(
                  label: 'Sessão fechada',
                  selected: _isClosed,
                  onTap: () => setState(() => _isClosed = true),
                ),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceXs),
          Text(
            _isClosed
                ? 'Quem usar o código ou link precisa pedir sua permissão para entrar.'
                : 'Qualquer pessoa com o código ou link entra direto na sessão.',
            style: ClippoText.label.copyWith(color: colors.textMuted),
          ),
          if (_pendingRequests.isNotEmpty) ...[
            const SizedBox(height: ClippoSpace.section),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedidos para entrar',
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                ),
                Text(
                  '${_pendingRequests.length}',
                  style: ClippoText.label.copyWith(
                    color: colors.accent,
                    fontFeatures: ClippoText.tabular,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClippoSpace.spaceM),
            for (var i = 0; i < _pendingRequests.length; i++) ...[
              if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
              _JoinRequestTile(
                person: _pendingRequests[i],
                onApprove: () => _approveJoinRequest(_pendingRequests[i]),
                onDecline: () => _declineJoinRequest(_pendingRequests[i]),
              ),
            ],
          ],
          const SizedBox(height: ClippoSpace.section),
          Text(
            'Participantes (${_selectedParticipants.length})',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Wrap(
            spacing: ClippoSpace.spaceM,
            runSpacing: ClippoSpace.spaceM,
            children: [
              for (final participant in _selectedParticipants)
                _EditableParticipantPill(
                  participant: participant,
                  isOwner: participant.uid == widget.session.ownerId,
                  onRemove: () => _removeParticipant(participant),
                ),
            ],
          ),
          if (unselected.isNotEmpty) ...[
            const SizedBox(height: ClippoSpace.section),
            Text(
              'Adicionar amigos',
              style: ClippoText.label.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: ClippoSpace.spaceM),
            Wrap(
              spacing: ClippoSpace.spaceM,
              runSpacing: ClippoSpace.spaceM,
              children: [
                for (final friend in unselected)
                  Semantics(
                    button: true,
                    label: 'Adicionar ${friend.name}',
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _addParticipant(friend),
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
                              Flexible(
                                child: Text(
                                  friend.firstName,
                                  style: ClippoText.label.copyWith(color: colors.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionAccessOptionTile extends StatelessWidget {
  const _SessionAccessOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.accentSoft : colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
              border: Border.all(
                color: selected ? colors.accent : colors.outline,
                width: ClippoSize.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: ClippoSpace.spaceM,
                vertical: ClippoSpace.spaceM,
              ),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClippoText.label.copyWith(
                    color: selected ? colors.accent : colors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinRequestTile extends StatelessWidget {
  const _JoinRequestTile({
    required this.person,
    required this.onApprove,
    required this.onDecline,
  });

  final SessionParticipant person;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

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
                    'Pediu para entrar na sessão',
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceS),
            Semantics(
              button: true,
              label: 'Aprovar entrada de ${person.name}',
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onApprove,
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
                        'Liberar',
                        style: ClippoText.label.copyWith(color: colors.onPrimary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceXs),
            Semantics(
              button: true,
              label: 'Recusar entrada de ${person.name}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDecline,
                child: SizedBox.square(
                  dimension: ClippoSize.minTouchTarget,
                  child: Center(
                    child: ClippoSvgIcon(
                      'close',
                      size: ClippoSize.checkIcon,
                      color: colors.textMuted,
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

class _EditableParticipantPill extends StatelessWidget {
  const _EditableParticipantPill({
    required this.participant,
    required this.isOwner,
    required this.onRemove,
  });

  final SessionParticipant participant;
  final bool isOwner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isOwner ? colors.accentSoft : colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
        border: Border.all(
          color: isOwner ? colors.accent : colors.outline,
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
            Flexible(
              child: Text(
                isOwner ? '${participant.firstName} (Criador)' : participant.firstName,
                style: ClippoText.label.copyWith(
                  color: isOwner ? colors.accent : colors.text,
                ),
              ),
            ),
            if (!isOwner) ...[
              const SizedBox(width: ClippoSpace.spaceS),
              Semantics(
                button: true,
                label: 'Remover ${participant.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: ClippoSvgIcon(
                    'close',
                    size: ClippoSize.checkIcon,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de usuários que participaram da sessão, com botão de adicionar amigo
/// para quem ainda não é amigo e toque para abrir o perfil de cada um.
class _SessionParticipantsScreen extends StatefulWidget {
  const _SessionParticipantsScreen({
    required this.session,
    required this.participants,
    required this.currentUserId,
    required this.isOwner,
    required this.availableFriends,
    required this.sentFriendRequests,
    required this.pendingJoinRequests,
    required this.onRemainingJoinRequestsChanged,
  });

  final Session session;
  final List<SessionParticipant> participants;
  final String currentUserId;
  final bool isOwner;
  final List<SessionParticipant> availableFriends;
  final Set<String> sentFriendRequests;
  final List<SessionParticipant> pendingJoinRequests;
  final ValueChanged<List<SessionParticipant>> onRemainingJoinRequestsChanged;

  @override
  State<_SessionParticipantsScreen> createState() => _SessionParticipantsScreenState();
}

class _SessionParticipantsScreenState extends State<_SessionParticipantsScreen> {
  late Session _session = widget.session;
  late List<SessionParticipant> _participants = widget.participants;
  late List<SessionParticipant> _joinRequests = widget.pendingJoinRequests;

  Set<String> get _friendUids =>
      widget.availableFriends.map((f) => f.uid).toSet();

  bool _isFriend(SessionParticipant p) => _friendUids.contains(p.uid);

  bool _isSelf(SessionParticipant p) => p.uid == widget.currentUserId;

  bool _isRequestSent(SessionParticipant p) =>
      widget.sentFriendRequests.contains(p.uid);

  void _sendFriendRequest(SessionParticipant participant) {
    setState(() {
      widget.sentFriendRequests.add(participant.uid);
    });
  }

  Future<void> _openParticipantProfile(SessionParticipant participant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ParticipantProfileScreen(
          participant: participant,
          isSessionOwner: participant.uid == _session.ownerId,
          isSelf: _isSelf(participant),
          isFriend: _isFriend(participant),
          initialRequestSent: _isRequestSent(participant),
          sessionName: _session.name,
          onSendFriendRequest: () => _sendFriendRequest(participant),
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _editParticipants() async {
    final result = await Navigator.of(context).push<_EditSessionResult>(
      MaterialPageRoute<_EditSessionResult>(
        builder: (_) => _EditSessionScreen(
          session: _session,
          currentParticipants: _participants,
          availableFriends: widget.availableFriends,
          pendingJoinRequests: _joinRequests,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _session = result.session;
        _participants = result.session.participants;
        _joinRequests = result.remainingRequests;
      });
      widget.onRemainingJoinRequestsChanged(result.remainingRequests);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return ClippoScreenGround(
      footer: widget.isOwner
          ? ClippoPrimaryButton(
              label: 'Editar participantes',
              onPressed: _editParticipants,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoBackButton(
            onPressed: () => Navigator.of(context).pop(_session),
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Jogaram',
            line2: 'juntos.',
            subtitle:
                '${clippoParticipantCount(_participants.length)} em ${_session.name}. Toque em alguém para ver o perfil.',
          ),
          const SizedBox(height: ClippoSpace.section),
          for (var i = 0; i < _participants.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _ParticipantRowTile(
              participant: _participants[i],
              isSessionOwner: _participants[i].uid == _session.ownerId,
              isSelf: _isSelf(_participants[i]),
              isFriend: _isFriend(_participants[i]),
              isRequestSent: _isRequestSent(_participants[i]),
              onTapProfile: () => _openParticipantProfile(_participants[i]),
              onAddFriend: () => _sendFriendRequest(_participants[i]),
              colors: colors,
            ),
          ],
        ],
      ),
    );
  }
}

class _ParticipantRowTile extends StatelessWidget {
  const _ParticipantRowTile({
    required this.participant,
    required this.isSessionOwner,
    required this.isSelf,
    required this.isFriend,
    required this.isRequestSent,
    required this.onTapProfile,
    required this.onAddFriend,
    required this.colors,
  });

  final SessionParticipant participant;
  final bool isSessionOwner;
  final bool isSelf;
  final bool isFriend;
  final bool isRequestSent;
  final VoidCallback onTapProfile;
  final VoidCallback onAddFriend;
  final ClippoColors colors;

  @override
  Widget build(BuildContext context) {
    final canAddFriend = !isSelf && !isFriend;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTapProfile,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ClippoSpace.cardPadding,
            vertical: ClippoSpace.fieldPaddingV,
          ),
          child: Row(
            children: [
              ClippoAvatar(
                name: participant.name,
                photoUrl: participant.photoUrl,
                size: ClippoSize.avatarLarge,
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            participant.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ClippoText.titleS.copyWith(color: colors.text),
                          ),
                        ),
                        if (isSessionOwner) ...[
                          const SizedBox(width: ClippoSpace.spaceS),
                          Text(
                            '· Criador',
                            style: ClippoText.label.copyWith(color: colors.accent),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(
                      '@${participant.displayUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClippoText.label.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              if (isFriend && !isSelf) ...[
                Text(
                  'Amigo',
                  style: ClippoText.label.copyWith(color: colors.textMuted),
                ),
                const SizedBox(width: ClippoSpace.spaceS),
              ] else if (canAddFriend) ...[
                _AddFriendChip(
                  participantName: participant.name,
                  sent: isRequestSent,
                  onPressed: onAddFriend,
                ),
                const SizedBox(width: ClippoSpace.spaceS),
              ],
              ClippoSvgIcon(
                'chevron-right',
                size: ClippoSize.checkIcon,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddFriendChip extends StatelessWidget {
  const _AddFriendChip({
    required this.participantName,
    required this.sent,
    required this.onPressed,
  });

  final String participantName;
  final bool sent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    if (sent) {
      return DecoratedBox(
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
      );
    }

    return Semantics(
      button: true,
      label: 'Adicionar amigo $participantName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
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
    );
  }
}

/// Perfil público de um participante da sessão.
class _ParticipantProfileScreen extends StatefulWidget {
  const _ParticipantProfileScreen({
    required this.participant,
    required this.isSessionOwner,
    required this.isSelf,
    required this.isFriend,
    required this.initialRequestSent,
    required this.sessionName,
    required this.onSendFriendRequest,
  });

  final SessionParticipant participant;
  final bool isSessionOwner;
  final bool isSelf;
  final bool isFriend;
  final bool initialRequestSent;
  final String sessionName;
  final VoidCallback onSendFriendRequest;

  @override
  State<_ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<_ParticipantProfileScreen> {
  late bool _requestSent = widget.initialRequestSent;

  void _handleAddFriend() {
    if (_requestSent) return;
    widget.onSendFriendRequest();
    setState(() => _requestSent = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final participant = widget.participant;
    final seed = participant.uid.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final sessionsCount = 4 + (seed % 14);
    final highlightsCount = 9 + (seed % 28);
    final friendsCount = 5 + (seed % 11);
    final togetherCount = 1 + (seed % 6);
    final canAddFriend = !widget.isSelf && !widget.isFriend;

    return ClippoScreenGround(
      footer: canAddFriend
          ? ClippoPrimaryButton(
              label: _requestSent ? 'Convite de amizade enviado' : 'Adicionar amigo',
              onPressed: _requestSent ? null : _handleAddFriend,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(label: 'Participantes'),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Perfil de',
            line2: '${participant.firstName}.',
            subtitle: widget.isSessionOwner
                ? 'Criou a sessão ${widget.sessionName}.'
                : 'Participou de ${widget.sessionName}.',
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
                    name: participant.name,
                    photoUrl: participant.photoUrl,
                    size: ClippoSize.avatarProfile,
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    participant.name,
                    textAlign: TextAlign.center,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    '@${participant.displayUsername}',
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: colors.accent),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    '$togetherCount sessões juntos',
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(
                      color: colors.textMuted,
                      fontFeatures: ClippoText.tabular,
                    ),
                  ),
                  if (widget.isFriend && !widget.isSelf) ...[
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
                          'Vocês já são amigos',
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
                child: _ProfileStatBox(
                  value: '$sessionsCount',
                  label: 'sessões',
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: _ProfileStatBox(
                  value: '$highlightsCount',
                  label: 'highlights',
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              Expanded(
                child: _ProfileStatBox(
                  value: '$friendsCount',
                  label: 'amigos',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStatBox extends StatelessWidget {
  const _ProfileStatBox({required this.value, required this.label});

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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ClippoText.label.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tela de compartilhamento da sessão por Link ou QR Code.
/// Exige que quem receber tenha o app Clippo baixado para acessar.
class _ShareSessionScreen extends StatefulWidget {
  const _ShareSessionScreen({required this.session});

  final Session session;

  @override
  State<_ShareSessionScreen> createState() => _ShareSessionScreenState();
}

class _ShareSessionScreenState extends State<_ShareSessionScreen> {
  bool _copied = false;

  String get _sessionLink => 'https://clippo.app/s/${widget.session.id}';

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _sessionLink));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: ClippoBrand.wine,
          content: Text(
            'Link copiado! Quem abrir precisa ter o app Clippo baixado.',
            style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _shareInvite() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: ClippoBrand.wine,
          content: Text(
            'Convite de ${widget.session.name} pronto para enviar.',
            style: ClippoText.label.copyWith(color: ClippoBrand.onWine),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(
            label: _copied ? 'Link copiado' : 'Copiar link da sessão',
            onPressed: _copyLink,
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: 'Compartilhar convite',
            onPressed: _shareInvite,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Compartilhar',
            line2: 'sessão.',
            subtitle: widget.session.name,
          ),
          const SizedBox(height: ClippoSpace.section),
          // Aviso de que é obrigatório ter o app baixado para acessar.
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
              border: Border.all(color: colors.accent, width: ClippoSize.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'É preciso ter o app Clippo baixado',
                    style: ClippoText.titleS.copyWith(color: colors.accent),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    'Quem receber o link ou escanear o QR Code deve ter o app Clippo instalado no celular e entrar na conta para ter acesso aos highlights desta sessão.',
                    style: ClippoText.body.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    widget.session.isClosed
                        ? 'Sessão fechada: quem usar o link ou QR Code enviará um pedido de permissão para o criador liberar a entrada.'
                        : 'Sessão aberta: quem abrir o link ou QR Code entra direto como participante.',
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceL),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                children: [
                  Text(
                    'QR Code da sessão',
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Semantics(
                    label: 'QR Code para abrir a sessão ${widget.session.name} no app Clippo',
                    child: Container(
                      width: ClippoSize.qrCode,
                      height: ClippoSize.qrCode,
                      padding: const EdgeInsets.all(ClippoSpace.spaceL),
                      decoration: BoxDecoration(
                        color: ClippoBrand.onWine,
                        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                      ),
                      child: CustomPaint(
                        painter: _SessionQrPainter(
                          data: _sessionLink,
                          color: ClippoBrand.onPeach,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    'Aponte a câmera com o app Clippo instalado.',
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
            ),
            child: Padding(
              padding: const EdgeInsets.all(ClippoSpace.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Link da sessão',
                    style: ClippoText.label.copyWith(color: colors.textLabel),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    _sessionLink,
                    style: ClippoText.input.copyWith(color: colors.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desenha uma matriz de QR Code 21×21 determinística a partir do link da sessão.
class _SessionQrPainter extends CustomPainter {
  const _SessionQrPainter({required this.data, required this.color});

  final String data;
  final Color color;

  static const int _grid = 21;

  bool _isFinderArea(int r, int c) {
    final topLeft = r < 8 && c < 8;
    final topRight = r < 8 && c >= _grid - 8;
    final bottomLeft = r >= _grid - 8 && c < 8;
    return topLeft || topRight || bottomLeft;
  }

  bool _isFinderModule(int r, int c) {
    bool inPattern(int pr, int pc) {
      final lr = r - pr;
      final lc = c - pc;
      if (lr < 0 || lr >= 7 || lc < 0 || lc >= 7) return false;
      if (lr == 0 || lr == 6 || lc == 0 || lc == 6) return true;
      if (lr >= 2 && lr <= 4 && lc >= 2 && lc <= 4) return true;
      return false;
    }

    return inPattern(0, 0) || inPattern(0, _grid - 7) || inPattern(_grid - 7, 0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _grid;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bytes = data.codeUnits;
    for (var r = 0; r < _grid; r++) {
      for (var c = 0; c < _grid; c++) {
        bool dark;
        if (_isFinderArea(r, c)) {
          dark = _isFinderModule(r, c);
        } else if (r == 6 || c == 6) {
          dark = (r + c).isEven;
        } else {
          final idx = (r * _grid + c) % bytes.length;
          final b = bytes[idx];
          dark = ((b + r * 7 + c * 13) & 1) == 0;
        }

        if (dark) {
          canvas.drawRect(
            Rect.fromLTWH(c * cell, r * cell, cell + 0.4, cell + 0.4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_SessionQrPainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
