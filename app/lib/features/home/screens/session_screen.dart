import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, setEquals;
import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/highlight_media_repository.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/upload/upload_queue.dart';
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
import 'package:clippo/features/home/screens/rename_highlight_screen.dart';
import 'package:clippo/features/home/widgets/home_feedback.dart';
import 'package:clippo/features/home/widgets/merge_request_card.dart';

/// 🟡 Participante pode sair sozinho da sessão? Decisão de produto em aberto
/// (docs/arquitetura.md › Participantes e hub da sessão). Mude para `false` para
/// esconder o "Sair da sessão" sem mexer no resto da tela.
const bool participantsCanLeaveSession = true;

/// Sessão: o hub dos lances de um jogo (docs/produto.md › 4.3).
///
/// Todo participante assiste e baixa qualquer lance (R11). Só o dono edita nome,
/// local e participantes (R12) e pede para juntar outra sessão do mesmo jogo (D18).
/// Ninguém entra por código, link ou QR: o dono adiciona entre os amigos dele.
///
/// Tudo o que vem do Firebase pode ser injetado pelo construtor, para a tela
/// abrir nos testes e no catálogo sem Firebase.
class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    this.session,
    this.highlights,
    this.currentUserId,
    this.repository,
    this.friendsRepository,
    this.mediaRepository,
    this.friendships,
    this.mySessions,
    this.mergeRequests,
    this.uploads,
    this.discardUploads,
  });

  /// Sessão aberta. Quando nula (catálogo), usa uma sessão de exemplo.
  final Session? session;

  /// Lances da sessão. No app, `sessionsRepository.watchHighlightsOf(session.id)`.
  final Stream<HighlightsSnapshot>? highlights;

  /// UID de quem está vendo. Nulo = quem está logado (ou o dono, no catálogo sem login).
  final String? currentUserId;

  /// Quem grava (editar, sair, juntar). No app, `sessionsRepository`.
  final SessionsRepository? repository;

  /// Pedido de amizade a partir da lista de participantes. No app, `friendsRepository`.
  final FriendsRepository? friendsRepository;

  /// Vídeos dos lances, repassado ao Player. No app, `highlightMediaRepository`.
  final HighlightMediaRepository? mediaRepository;

  /// Amizades de quem está vendo: os aceitos são quem o dono pode adicionar (R10).
  final Stream<List<Friendship>>? friendships;

  /// Minhas sessões: mantêm o cabeçalho em dia e dão os candidatos a juntar (D18).
  final Stream<SessionsSnapshot>? mySessions;

  /// Pedidos para juntar sessões em que estou (D18).
  final Stream<List<SessionMergeRequest>>? mergeRequests;

  /// Lances ainda no celular de quem gravou, para assistir antes de subir (R13). No app,
  /// `uploadQueue` (com alguém logado).
  final ValueListenable<UploadQueueState>? uploads;

  /// Tira a sessão da fila de envio e apaga do aparelho os vídeos que ainda não subiram, antes
  /// de excluir no servidor. No app, `uploadQueue.discard` (com alguém logado).
  final Future<void> Function(String sessionId)? discardUploads;

  static final Session _demoSession = Session(
    id: 'pelada-quinta-11set',
    name: 'Pelada de quinta',
    ownerId: 'gustavo',
    participantIds: const ['gustavo', 'rafa', 'bruno'],
    participants: const [
      SessionParticipant(uid: 'gustavo', name: 'Gustavo Alves', username: 'gustavo.alves'),
      SessionParticipant(uid: 'rafa', name: 'Rafa Costa', username: 'rafa.costa'),
      SessionParticipant(uid: 'bruno', name: 'Bruno Lima', username: 'bruno.lima'),
    ],
    participantCount: 3,
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
      title: 'Lance 3',
      offset: const Duration(minutes: 27, seconds: 8),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 19, 57, 8),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-4',
      title: 'Lance 4',
      offset: const Duration(minutes: 41, seconds: 50),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 20, 11, 50),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-5',
      title: 'Lance 5',
      offset: const Duration(minutes: 58, seconds: 12),
      duration: const Duration(seconds: 30),
      savedAt: DateTime(2026, 9, 11, 20, 28, 12),
      createdBy: 'gustavo',
    ),
    Highlight(
      id: 'hl-6',
      title: 'Lance 6',
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
  late Stream<HighlightsSnapshot> _highlights = _resolveHighlights();

  List<Friend> _friends = const [];
  Set<String> _outgoingFriendUids = const {};
  final Set<String> _sentFriendRequests = <String>{};
  List<Session> _mySessions = const [];
  List<SessionMergeRequest> _mergeRequests = const [];
  final Set<String> _busyRequests = <String>{};
  bool _leaving = false;
  bool _deleting = false;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  SessionsRepository get _repository => widget.repository ?? sessionsRepository;

  /// A fila de envio: sem ela (catálogo, testes sem login), nenhum lance local.
  ValueListenable<UploadQueueState> get _uploads =>
      widget.uploads ?? (isUserSignedIn ? uploadQueue.state : _noUploads);
  static final ValueNotifier<UploadQueueState> _noUploads = ValueNotifier(const UploadQueueState());
  /// As miniaturas dos lances. Sem login (catálogo, testes), nenhuma.
  HighlightMediaRepository? get _media =>
      widget.mediaRepository ?? (isUserSignedIn ? highlightMediaRepository : null);
  FriendsRepository get _friendsRepo => widget.friendsRepository ?? friendsRepository;

  String get _viewerId {
    if (widget.currentUserId != null) return widget.currentUserId!;
    if (isUserSignedIn) return authRepository.currentUser!.uid;
    // Catálogo sem login: vê como o dono, para dar para testar a edição.
    return _session.ownerId;
  }

  bool get _isOwner => _session.isOwnedBy(_viewerId);

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  void _listen() {
    final signedIn = isUserSignedIn;
    final friendships = widget.friendships ??
        (signedIn ? friendsRepository.watchFriendships() : Stream.value(const <Friendship>[]));
    final mySessions = widget.mySessions ??
        (signedIn
            ? sessionsRepository.watchMySessions()
            : Stream.value(const SessionsSnapshot(sessions: [], fromCache: false)));
    final mergeRequests = widget.mergeRequests ??
        (signedIn
            ? sessionsRepository.watchMergeRequests()
            : Stream.value(const <SessionMergeRequest>[]));

    // Sem amigos, pedidos ou a lista de sessões a tela continua útil (assistir e
    // baixar); por isso um erro nesses streams só deixa a lista vazia.
    _subscriptions
      ..add(friendships.listen((items) {
        if (!mounted) return;
        setState(() {
          _friends = [for (final f in items) if (f.isAccepted) f.other];
          _outgoingFriendUids = {
            for (final f in items)
              if (f.isOutgoingFor(_viewerId)) f.other.uid,
          };
        });
      }, onError: (Object _) {}))
      ..add(mySessions.listen((snapshot) {
        if (!mounted) return;
        setState(() {
          _mySessions = snapshot.sessions;
          if (widget.session != null) {
            for (final s in snapshot.sessions) {
              if (s.id == _session.id) _session = s;
            }
          }
        });
      }, onError: (Object _) {}))
      ..add(mergeRequests.listen((items) {
        if (!mounted) return;
        setState(() => _mergeRequests = items);
      }, onError: (Object _) {}));
  }

  @override
  void didUpdateWidget(covariant SessionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session != oldWidget.session && widget.session != null) {
      _session = widget.session!;
    }
    if (widget.highlights != oldWidget.highlights) {
      _highlights = _resolveHighlights();
    }
  }

  Stream<HighlightsSnapshot> _resolveHighlights() {
    if (widget.highlights != null) return widget.highlights!;
    if (widget.session != null && isUserSignedIn) {
      return sessionsRepository.watchHighlightsOf(widget.session!.id);
    }
    return Stream<HighlightsSnapshot>.value(
      HighlightsSnapshot(highlights: SessionScreen._demoHighlights, fromCache: false),
    );
  }

  void _retry() => setState(() => _highlights = _resolveHighlights());

  /// Os participantes com nome: a cópia da sessão tem só os 5 primeiros; o resto
  /// vem dos amigos. Quem não está em nenhum dos dois aparece como "Participante".
  List<SessionParticipant> _participantsOf(Session session) {
    final byId = <String, SessionParticipant>{
      for (final f in _friends)
        f.uid: SessionParticipant(
          uid: f.uid,
          name: f.name,
          username: f.username,
          photoUrl: f.photoUrl,
        ),
      for (final p in session.participants) p.uid: p,
    };
    final ids = session.participantIds.isNotEmpty
        ? session.participantIds
        : [for (final p in session.participants) p.uid];
    return [
      for (final uid in ids) byId[uid] ?? SessionParticipant(uid: uid, name: 'Participante'),
    ];
  }

  /// Pedidos de juntar que envolvem esta sessão, como principal ou como origem.
  List<SessionMergeRequest> get _requestsHere => _mergeRequests
      .where((r) => r.intoSessionId == _session.id || r.fromSessionId == _session.id)
      .toList(growable: false);

  void _openPlayer(List<Highlight> items, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          sessionName: _session.name,
          highlights: items,
          initialIndex: index,
          mediaRepository: widget.mediaRepository,
        ),
      ),
    );
  }

  /// Só o dono renomeia, e só lances que já estão no servidor (o `saveSession` já respondeu).
  bool _canRename(Highlight highlight) => _isOwner && (highlight.videoPath ?? '').isNotEmpty;

  Future<void> _openRename(Highlight highlight) async {
    final renamed = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => RenameHighlightScreen(
          sessionId: _session.id,
          highlight: highlight,
          repository: _repository,
        ),
      ),
    );
    // O Firestore atualiza o card sozinho; aqui só o aviso.
    if (renamed != null && mounted) showHomeMessage(context, 'Lance renomeado.');
  }

  Future<Session?> _openEditSession() async {
    if (!_isOwner) return null;
    final updated = await Navigator.of(context).push<Session>(
      MaterialPageRoute<Session>(
        builder: (_) => _EditSessionScreen(
          session: _session,
          participants: _participantsOf(_session),
          friends: _friends,
          repository: _repository,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _session = updated);
      showHomeMessage(context, 'Sessão atualizada.');
    }
    return updated;
  }

  Future<void> _openParticipants() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SessionParticipantsScreen(
          session: _session,
          participantsOf: _participantsOf,
          viewerId: _viewerId,
          isOwner: _isOwner,
          friendUids: {for (final f in _friends) f.uid},
          sentFriendRequests: {..._outgoingFriendUids, ..._sentFriendRequests},
          mySessions: _mySessions,
          onSendFriendRequest: _sendFriendRequest,
          onEdit: _openEditSession,
        ),
      ),
    );
  }

  /// Manda o pedido de amizade pelo @ do participante. Devolve true se deu certo.
  Future<bool> _sendFriendRequest(SessionParticipant participant) async {
    final username = participant.username;
    if (username == null || username.trim().isEmpty) return false;
    try {
      await _friendsRepo.sendFriendRequest(username);
      if (!mounted) return true;
      setState(() => _sentFriendRequests.add(participant.uid));
      showHomeMessage(context, 'Pedido enviado para ${participant.firstName}.');
      return true;
    } on FriendsFailure catch (e) {
      if (mounted) showHomeMessage(context, e.message);
    } catch (e) {
      if (mounted) showHomeMessage(context, FriendsFailure.from(e).message);
    }
    return false;
  }

  Future<void> _openMerge() async {
    final pendingFrom = {
      for (final r in _mergeRequests)
        if (r.intoSessionId == _session.id) r.fromSessionId,
    };
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _MergeSessionScreen(
          into: _session,
          candidates: SessionsRepository.mergeCandidates(_session, _mySessions),
          pendingFromIds: pendingFrom,
          repository: _repository,
        ),
      ),
    );
    if (sent == true && mounted) {
      showHomeMessage(context, 'Pedido enviado. Os lances juntam quando o outro dono aceitar.');
    }
  }

  Future<void> _answerMerge(SessionMergeRequest request, {required bool accept}) async {
    setState(() => _busyRequests.add(request.id));
    try {
      if (accept) {
        await _repository.acceptSessionMerge(request.id);
      } else {
        await _repository.cancelSessionMerge(request.id);
      }
      if (!mounted) return;
      setState(() => _mergeRequests = [
            for (final r in _mergeRequests)
              if (r.id != request.id) r,
          ]);
      if (accept && request.fromSessionId == _session.id) {
        // Esta sessão acabou de virar parte da outra: a Início deixa de mostrá-la.
        showHomeMessage(context, 'Sessões juntadas. Os lances agora estão em ${request.intoName}.');
        Navigator.of(context).maybePop();
        return;
      }
      showHomeMessage(context, accept ? 'Sessões juntadas.' : 'Pedido cancelado.');
    } catch (e) {
      if (mounted) showHomeMessage(context, SessionsFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _busyRequests.remove(request.id));
    }
  }

  /// O dono exclui a sessão para todos (deleteSession). Primeiro sai da fila de envio deste
  /// aparelho (os lances que ainda não subiram não voltam a subir), depois o servidor apaga.
  Future<void> _delete() async {
    final name = _session.name;
    final count = _session.highlightCount;
    final confirmed = await confirmHomeAction(
      context,
      title: 'Excluir sessão?',
      message: count == 0
          ? '$name some para todos os participantes. Não dá para desfazer.'
          : '$name e ${clippoHighlightCount(count)} somem para todos os participantes. '
              'Não dá para desfazer.',
      confirmLabel: 'Excluir sessão',
      cancelLabel: 'Manter sessão',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      final discard = widget.discardUploads ?? (isUserSignedIn ? uploadQueue.discard : null);
      await discard?.call(_session.id);
      await _repository.deleteSession(_session.id);
      if (!mounted) return;
      showHomeMessage(context, 'Sessão excluída.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) showHomeMessage(context, SessionsFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await confirmHomeAction(
      context,
      title: 'Sair da sessão?',
      message: 'Você deixa de ver os lances de ${_session.name}. '
          'Para voltar, o dono precisa te adicionar de novo.',
      confirmLabel: 'Sair da sessão',
      cancelLabel: 'Ficar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _leaving = true);
    try {
      await _repository.leaveSession(_session.id);
      if (!mounted) return;
      showHomeMessage(context, 'Você saiu de ${_session.name}.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) showHomeMessage(context, SessionsFailure.from(e).message);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final requests = _requestsHere;

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: ClippoBackButton(label: 'Sessões')),
              if (_isOwner)
                _HeaderIconButton(
                  icon: 'edit',
                  semanticLabel: 'Editar sessão',
                  onPressed: _openEditSession,
                ),
            ],
          ),
          const SizedBox(height: ClippoSpace.section),
          _SessionHeader(session: session, onTapParticipants: _openParticipants),
          for (final request in requests) ...[
            const SizedBox(height: ClippoSpace.spaceL),
            MergeRequestCard(
              request: request,
              viewerId: _viewerId,
              busy: _busyRequests.contains(request.id),
              onAccept: () => _answerMerge(request, accept: true),
              onCancel: () => _answerMerge(request, accept: false),
            ),
          ],
          const SizedBox(height: ClippoSpace.section),
          ValueListenableBuilder<UploadQueueState>(
            valueListenable: _uploads,
            builder: (context, queue, _) => StreamBuilder<HighlightsSnapshot>(
            stream: _highlights,
            builder: (context, snapshot) {
              final data = snapshot.data;
              // Os lances que ainda estão no celular aparecem mesmo sem internet (R13).
              final withLocal = queue.withLocalVideos(session.id, data?.highlights ?? const []);
              if (withLocal.any((h) => h.hasLocalVideo)) {
                return _HighlightList(
                  highlights: withLocal,
                  offline: data?.fromCache ?? false,
                  media: _media,
                  onTapHighlight: (index) => _openPlayer(withLocal, index),
                  canRename: _canRename,
                  onRename: _openRename,
                );
              }
              if (snapshot.hasError) {
                return _Problem(failure: SessionsFailure.from(snapshot.error!), onRetry: _retry);
              }
              if (snapshot.connectionState == ConnectionState.waiting || data == null) {
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
              if (data.isEmpty) return const _Empty();

              final items = data.highlights;
              return _HighlightList(
                highlights: items,
                offline: data.fromCache,
                media: _media,
                onTapHighlight: (index) => _openPlayer(items, index),
                canRename: _canRename,
                onRename: _openRename,
              );
            },
            ),
          ),
          const SizedBox(height: ClippoSpace.section),
          if (_isOwner) ...[
            ClippoTextButton(label: 'Juntar com outra sessão', onPressed: _openMerge),
            const SizedBox(height: ClippoSpace.spaceS),
            ClippoTextButton(
              label: _deleting ? 'Excluindo…' : 'Excluir sessão',
              onPressed: _deleting ? null : _delete,
            ),
          ] else if (participantsCanLeaveSession)
            ClippoTextButton(label: 'Sair da sessão', onPressed: _leaving ? null : _leave),
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
                decoration: BoxDecoration(color: colors.controlSoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: ClippoSvgIcon(icon, size: ClippoSize.fieldIcon, color: colors.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho da Sessão: título em duas linhas, "data · duração", local e
/// participantes clicáveis.
class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session, required this.onTapParticipants});

  final Session session;
  final VoidCallback onTapParticipants;

  (String, String) _splitTitle(String rawName) {
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return ('Sua', 'sessão.');
    final withoutTrailingDot =
        trimmed.endsWith('.') ? trimmed.substring(0, trimmed.length - 1).trim() : trimmed;
    final words = withoutTrailingDot.split(RegExp(r'\s+'));
    if (words.length == 1) return ('Sessão', '${words.first}.');
    return (words.sublist(0, words.length - 1).join(' '), '${words.last}.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final (line1, line2) = _splitTitle(session.name);
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
          subtitle: clippoDotList([clippoDate(session.startedAt), clippoDuration(session.duration)]),
        ),
        if (place != null && place.isNotEmpty) ...[
          const SizedBox(height: ClippoSpace.spaceM),
          Row(
            children: [
              ClippoSvgIcon('map-pin', size: ClippoSize.checkIcon, color: colors.accent),
              const SizedBox(width: ClippoSpace.spaceS),
              Flexible(
                child: Text(place, style: ClippoText.body.copyWith(color: colors.textMuted)),
              ),
            ],
          ),
        ],
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
                      ClippoAvatarRow(people: visiblePeople, hidden: hiddenCount, ring: colors.surface),
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
                    ClippoSvgIcon('chevron-right', size: ClippoSize.checkIcon, color: colors.textMuted),
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
        Expanded(child: Text('Highlights', style: ClippoText.titleS.copyWith(color: colors.text))),
        const SizedBox(width: ClippoSpace.spaceM),
        Text(
          clippoSavedPlaysCount(count),
          style: ClippoText.label.copyWith(color: colors.textMuted, fontFeatures: ClippoText.tabular),
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
    this.media,
    this.canRename,
    this.onRename,
  });

  final List<Highlight> highlights;
  final bool offline;
  final ValueChanged<int> onTapHighlight;

  /// Quais lances mostram "Renomear" (só o dono da sessão). Nulo: nenhum.
  final bool Function(Highlight)? canRename;
  final ValueChanged<Highlight>? onRename;

  /// De onde vêm as miniaturas já enviadas. Nulo (catálogo, testes): só o desenho de quadra.
  final HighlightMediaRepository? media;

  Widget _buildCard(int index) {
    final item = highlights[index];
    return _HighlightCard(
      key: ValueKey(item.id),
      highlight: item,
      media: media,
      onTap: () => onTapHighlight(index),
      onRename: onRename != null && (canRename?.call(item) ?? false) ? () => onRename!(item) : null,
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
                  child: i + 1 < highlights.length ? _buildCard(i + 1) : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Um card de highlight com a miniatura certa: a do celular enquanto o lance ainda está na
/// fila de envio ([Highlight.localThumbnailPath]); depois, a do Storage, baixada com o login
/// de quem vê (D17: sem `getDownloadURL()`). Sem miniatura, o card desenha a quadra.
class _HighlightCard extends StatefulWidget {
  const _HighlightCard({
    super.key,
    required this.highlight,
    required this.onTap,
    this.media,
    this.onRename,
  });

  final Highlight highlight;
  final HighlightMediaRepository? media;
  final VoidCallback onTap;
  final VoidCallback? onRename;

  @override
  State<_HighlightCard> createState() => _HighlightCardState();
}

class _HighlightCardState extends State<_HighlightCard> {
  /// O pedido em andamento (ou já respondido) e para o quê ele foi feito.
  String? _requested;
  File? _downloaded;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_HighlightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final item = widget.highlight;
    final media = widget.media;
    final path = item.thumbnailPath;
    // Quem gravou usa a miniatura do aparelho enquanto o lance está na fila.
    if (media == null || path == null || item.hasLocalVideo || _downloaded != null) return;
    // A miniatura pode chegar depois: quando o estado do lance muda, vale pedir de novo.
    final request = '$path|${item.status.name}';
    if (_requested == request) return;
    _requested = request;
    try {
      final file = await media.thumbnailFile(path);
      if (mounted) setState(() => _downloaded = file);
    } catch (_) {
      // Ainda não subiu, lance antigo sem miniatura ou sem internet: fica o desenho de quadra.
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.highlight;
    final local = item.localThumbnailPath;
    final file = local != null && local.isNotEmpty ? File(local) : _downloaded;
    return ClippoHighlightTile(
      title: item.title,
      timing: clippoHighlightTiming(item.offset, item.duration, uploading: item.isUploading),
      uploading: item.isUploading,
      thumbnail: file == null ? null : FileImage(file),
      onTap: widget.onTap,
      onRename: widget.onRename,
    );
  }
}

/// Esqueletos dos cards enquanto os highlights carregam.
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

/// Sessão sem lances salvos (docs/produto.md › 4.3).
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
        Text('Nenhum lance salvo nessa sessão', style: ClippoText.titleS.copyWith(color: colors.text)),
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

/// Editar a sessão — só o dono (R12). Salva por `updateSession`, com a validação de
/// input_validation.dart embaixo de cada campo, e devolve a sessão atualizada.
class _EditSessionScreen extends StatefulWidget {
  const _EditSessionScreen({
    required this.session,
    required this.participants,
    required this.friends,
    required this.repository,
  });

  final Session session;
  final List<SessionParticipant> participants;

  /// Amigos aceitos do dono: só eles podem entrar (R10, conferido de novo no servidor).
  final List<Friend> friends;
  final SessionsRepository repository;

  @override
  State<_EditSessionScreen> createState() => _EditSessionScreenState();
}

class _EditSessionScreenState extends State<_EditSessionScreen> {
  late final TextEditingController _nameController = TextEditingController(text: widget.session.name);
  late final TextEditingController _locationController =
      TextEditingController(text: widget.session.location?.label ?? '');
  late final List<SessionParticipant> _selected = List<SessionParticipant>.of(widget.participants);

  String? _nameError;
  String? _locationError;
  String? _participantsError;
  String? _generalError;
  bool _saving = false;

  String get _ownerId => widget.session.ownerId;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  List<Friend> get _addable => widget.friends
      .where((f) => f.uid != _ownerId && _selected.every((p) => p.uid != f.uid))
      .toList(growable: false);

  /// Os participantes, sem o dono (ele entra sozinho, R9).
  List<String> get _selectedIds => [
        for (final p in _selected)
          if (p.uid != _ownerId) p.uid,
      ];

  void _remove(SessionParticipant participant) {
    if (participant.uid == _ownerId) return;
    setState(() {
      _selected.removeWhere((p) => p.uid == participant.uid);
      _participantsError = null;
    });
  }

  void _add(Friend friend) {
    setState(() {
      _selected.add(SessionParticipant(
        uid: friend.uid,
        name: friend.name,
        username: friend.username,
        photoUrl: friend.photoUrl,
      ));
      _participantsError = null;
    });
  }

  Future<void> _submit() async {
    final ids = _selectedIds;
    final nameErr = validateSessionName(_nameController.text);
    final locErr = validateLocation(_locationController.text);
    final partErr = validateParticipantIds(ids, ownerId: _ownerId);
    setState(() {
      _nameError = nameErr;
      _locationError = locErr;
      _participantsError = partErr;
      _generalError = null;
    });
    if (nameErr != null || locErr != null || partErr != null) return;

    final location = normalizeLocation(_locationController.text);
    final hadLocation = (widget.session.location?.label ?? '').trim().isNotEmpty;
    final before = {
      for (final uid in widget.session.participantIds)
        if (uid != _ownerId) uid,
    };
    final participantsChanged = !setEquals(before, ids.toSet());

    setState(() => _saving = true);
    try {
      await widget.repository.updateSession(
        sessionId: widget.session.id,
        name: _nameController.text,
        location: location,
        clearLocation: location == null && hadLocation,
        participantIds: participantsChanged ? ids : null,
      );
      if (!mounted) return;
      final allIds = normalizeParticipantIds(ids, ownerId: _ownerId);
      Navigator.of(context).pop(widget.session.copyWith(
        name: normalizeSessionName(_nameController.text),
        location: location == null ? null : SessionLocation(label: location),
        clearLocation: location == null,
        participantIds: allIds,
        participants: List<SessionParticipant>.unmodifiable(_selected),
        participantCount: allIds.length,
      ));
    } catch (e) {
      if (!mounted) return;
      final failure = SessionsFailure.from(e);
      setState(() {
        _saving = false;
        // O servidor diz qual campo falhou; a mensagem vai embaixo dele.
        switch (failure.code) {
          case 'name':
            _nameError = failure.message;
          case 'location':
            _locationError = failure.message;
          case 'participantIds':
            _participantsError = failure.message;
          default:
            _generalError = failure.message;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final addable = _addable;

    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_generalError != null) ...[
            Text(_generalError!, style: ClippoText.label.copyWith(color: colors.error)),
            const SizedBox(height: ClippoSpace.spaceM),
          ],
          ClippoPrimaryButton(label: 'Salvar alterações', onPressed: _submit, loading: _saving),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          const ClippoScreenTitle(
            line1: 'Editar',
            line2: 'sessão.',
            subtitle: 'Só quem gravou muda o nome, o local e quem jogou.',
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
            'Participantes (${_selected.length})',
            style: ClippoText.titleS.copyWith(color: colors.text),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Wrap(
            spacing: ClippoSpace.spaceM,
            runSpacing: ClippoSpace.spaceM,
            children: [
              for (final participant in _selected)
                _EditableParticipantPill(
                  participant: participant,
                  isOwner: participant.uid == _ownerId,
                  onRemove: () => _remove(participant),
                ),
            ],
          ),
          if (_participantsError != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Text(_participantsError!, style: ClippoText.label.copyWith(color: colors.error)),
          ],
          const SizedBox(height: ClippoSpace.section),
          Text('Adicionar amigos', style: ClippoText.label.copyWith(color: colors.textMuted)),
          const SizedBox(height: ClippoSpace.spaceM),
          if (addable.isEmpty)
            Text(
              widget.friends.isEmpty
                  ? 'Só dá para adicionar seus amigos. Adicione amigos na aba Amigos.'
                  : 'Todos os seus amigos já estão na sessão.',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            )
          else
            Wrap(
              spacing: ClippoSpace.spaceM,
              runSpacing: ClippoSpace.spaceM,
              children: [
                for (final friend in addable)
                  Semantics(
                    button: true,
                    label: 'Adicionar ${friend.name}',
                    excludeSemantics: true,
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => _add(friend),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ClippoSpace.spaceL,
                            vertical: ClippoSpace.spaceM,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClippoSvgIcon('plus', size: ClippoSize.checkIcon, color: colors.accent),
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
        border: Border.all(color: isOwner ? colors.accent : colors.outline, width: ClippoSize.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL, vertical: ClippoSpace.spaceM),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                isOwner ? '${participant.firstName} (Criador)' : participant.firstName,
                style: ClippoText.label.copyWith(color: isOwner ? colors.accent : colors.text),
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
                  child: ClippoSvgIcon('close', size: ClippoSize.checkIcon, color: colors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Quem jogou: toque abre o perfil; "Adicionar" manda pedido de amizade pelo @.
class _SessionParticipantsScreen extends StatefulWidget {
  const _SessionParticipantsScreen({
    required this.session,
    required this.participantsOf,
    required this.viewerId,
    required this.isOwner,
    required this.friendUids,
    required this.sentFriendRequests,
    required this.mySessions,
    required this.onSendFriendRequest,
    required this.onEdit,
  });

  final Session session;
  final List<SessionParticipant> Function(Session) participantsOf;
  final String viewerId;
  final bool isOwner;
  final Set<String> friendUids;
  final Set<String> sentFriendRequests;
  final List<Session> mySessions;
  final Future<bool> Function(SessionParticipant) onSendFriendRequest;
  final Future<Session?> Function() onEdit;

  @override
  State<_SessionParticipantsScreen> createState() => _SessionParticipantsScreenState();
}

class _SessionParticipantsScreenState extends State<_SessionParticipantsScreen> {
  late Session _session = widget.session;
  late List<SessionParticipant> _participants = widget.participantsOf(_session);
  late final Set<String> _sent = {...widget.sentFriendRequests};

  /// Pedidos de amizade a caminho do servidor: o botão mostra que está enviando.
  final Set<String> _sending = <String>{};

  bool _isFriend(SessionParticipant p) => widget.friendUids.contains(p.uid);
  bool _isSelf(SessionParticipant p) => p.uid == widget.viewerId;
  bool _canAsk(SessionParticipant p) => (p.username ?? '').trim().isNotEmpty;

  Future<bool> _sendFriendRequest(SessionParticipant participant) async {
    if (_sending.contains(participant.uid)) return false;
    setState(() => _sending.add(participant.uid));
    try {
      final ok = await widget.onSendFriendRequest(participant);
      if (ok && mounted) setState(() => _sent.add(participant.uid));
      return ok;
    } finally {
      if (mounted) setState(() => _sending.remove(participant.uid));
    }
  }

  Future<void> _openProfile(SessionParticipant participant) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ParticipantProfileScreen(
          participant: participant,
          isSessionOwner: participant.uid == _session.ownerId,
          isSelf: _isSelf(participant),
          isFriend: _isFriend(participant),
          canAsk: _canAsk(participant),
          initialRequestSent: _sent.contains(participant.uid),
          sessionName: _session.name,
          sessionsTogether:
              FriendsRepository.sessionsTogether(widget.viewerId, participant.uid, widget.mySessions),
          onSendFriendRequest: () => _sendFriendRequest(participant),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit() async {
    final updated = await widget.onEdit();
    if (updated != null && mounted) {
      setState(() {
        _session = updated;
        _participants = widget.participantsOf(updated);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final unnamed = _session.participantCount - _participants.length;

    return ClippoScreenGround(
      footer: widget.isOwner ? ClippoPrimaryButton(label: 'Editar participantes', onPressed: _edit) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Jogaram',
            line2: 'juntos.',
            subtitle: '${clippoParticipantCount(_session.participantCount)} em ${_session.name}. '
                'Toque em alguém para ver o perfil.',
          ),
          const SizedBox(height: ClippoSpace.section),
          for (var i = 0; i < _participants.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _ParticipantRowTile(
              participant: _participants[i],
              isSessionOwner: _participants[i].uid == _session.ownerId,
              isSelf: _isSelf(_participants[i]),
              isFriend: _isFriend(_participants[i]),
              canAsk: _canAsk(_participants[i]),
              isRequestSent: _sent.contains(_participants[i].uid),
              isSending: _sending.contains(_participants[i].uid),
              onTapProfile: () => _openProfile(_participants[i]),
              onAddFriend: () => _sendFriendRequest(_participants[i]),
            ),
          ],
          if (unnamed > 0) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Text(
              unnamed == 1 ? 'E mais 1 pessoa.' : 'E mais $unnamed pessoas.',
              style: ClippoText.label.copyWith(color: colors.textMuted),
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
    required this.canAsk,
    required this.isRequestSent,
    required this.onTapProfile,
    required this.onAddFriend,
    this.isSending = false,
  });

  final SessionParticipant participant;
  final bool isSessionOwner;
  final bool isSelf;
  final bool isFriend;
  final bool canAsk;
  final bool isRequestSent;

  /// O pedido de amizade está a caminho do servidor.
  final bool isSending;
  final VoidCallback onTapProfile;
  final VoidCallback onAddFriend;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final canAddFriend = !isSelf && !isFriend && canAsk;

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
              ClippoAvatar(name: participant.name, photoUrl: participant.photoUrl, size: ClippoSize.avatarLarge),
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
                          Text('· Criador', style: ClippoText.label.copyWith(color: colors.accent)),
                        ],
                      ],
                    ),
                    if (canAsk) ...[
                      const SizedBox(height: ClippoSpace.labelToValue),
                      Text(
                        '@${participant.displayUsername}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ClippoText.label.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              if (isFriend && !isSelf) ...[
                Text('Amigo', style: ClippoText.label.copyWith(color: colors.textMuted)),
                const SizedBox(width: ClippoSpace.spaceS),
              ] else if (canAddFriend) ...[
                _AddFriendChip(
                  participantName: participant.name,
                  sent: isRequestSent,
                  sending: isSending,
                  onPressed: onAddFriend,
                ),
                const SizedBox(width: ClippoSpace.spaceS),
              ],
              ClippoSvgIcon('chevron-right', size: ClippoSize.checkIcon, color: colors.textMuted),
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
    this.sending = false,
  });

  final String participantName;
  final bool sent;

  /// Enviando o pedido: mostra que está trabalhando e não aceita outro toque.
  final bool sending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    const padding = EdgeInsets.symmetric(horizontal: ClippoSpace.spaceM, vertical: ClippoSpace.spaceS);

    if (sent) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: colors.controlSoft,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
        ),
        child: Padding(
          padding: padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClippoSvgIcon('check', size: ClippoSize.checkIcon, color: colors.accent),
              const SizedBox(width: ClippoSpace.spaceXs),
              Text('Enviado', style: ClippoText.label.copyWith(color: colors.accent)),
            ],
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: !sending,
      label: sending ? 'Enviando pedido para $participantName' : 'Adicionar amigo $participantName',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Enviando: o toque fica no botão (não abre o perfil da linha) e não faz nada.
        onTap: sending ? () {} : onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
            border: Border.all(color: colors.accent, width: ClippoSize.border),
          ),
          child: Padding(
            padding: padding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sending)
                  SizedBox.square(
                    dimension: ClippoSize.checkIcon,
                    child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: colors.accent),
                  )
                else
                  ClippoSvgIcon('plus', size: ClippoSize.checkIcon, color: colors.accent),
                const SizedBox(width: ClippoSpace.spaceXs),
                Text(sending ? 'Enviando…' : 'Adicionar', style: ClippoText.label.copyWith(color: colors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Perfil de um participante, com o que o app sabe de verdade: nome, @ e quantas
/// sessões vocês jogaram juntos (R16, contado nas sessões que a Início já leu).
class _ParticipantProfileScreen extends StatefulWidget {
  const _ParticipantProfileScreen({
    required this.participant,
    required this.isSessionOwner,
    required this.isSelf,
    required this.isFriend,
    required this.canAsk,
    required this.initialRequestSent,
    required this.sessionName,
    required this.sessionsTogether,
    required this.onSendFriendRequest,
  });

  final SessionParticipant participant;
  final bool isSessionOwner;
  final bool isSelf;
  final bool isFriend;
  final bool canAsk;
  final bool initialRequestSent;
  final String sessionName;
  final int sessionsTogether;
  final Future<bool> Function() onSendFriendRequest;

  @override
  State<_ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<_ParticipantProfileScreen> {
  late bool _requestSent = widget.initialRequestSent;
  bool _sending = false;

  Future<void> _handleAddFriend() async {
    if (_requestSent || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.onSendFriendRequest();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _requestSent = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final participant = widget.participant;
    final canAddFriend = !widget.isSelf && !widget.isFriend && widget.canAsk;

    return ClippoScreenGround(
      footer: canAddFriend
          ? ClippoPrimaryButton(
              label: _requestSent ? 'Pedido de amizade enviado' : 'Adicionar amigo',
              onPressed: _requestSent ? null : _handleAddFriend,
              loading: _sending,
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
                ? 'Gravou a sessão ${widget.sessionName}.'
                : 'Jogou em ${widget.sessionName}.',
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
                  ClippoAvatar(name: participant.name, photoUrl: participant.photoUrl, size: ClippoSize.avatarProfile),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    participant.name,
                    textAlign: TextAlign.center,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  if (widget.canAsk) ...[
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(
                      '@${participant.displayUsername}',
                      textAlign: TextAlign.center,
                      style: ClippoText.label.copyWith(color: colors.accent),
                    ),
                  ],
                  if (!widget.isSelf) ...[
                    const SizedBox(height: ClippoSpace.spaceM),
                    Text(
                      clippoSharedSessionsCount(widget.sessionsTogether),
                      textAlign: TextAlign.center,
                      style: ClippoText.label.copyWith(color: colors.textMuted, fontFeatures: ClippoText.tabular),
                    ),
                  ],
                  if (widget.isFriend && !widget.isSelf) ...[
                    const SizedBox(height: ClippoSpace.spaceM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClippoSvgIcon('check', size: ClippoSize.checkIcon, color: colors.accent),
                        const SizedBox(width: ClippoSpace.spaceXs),
                        Text('Vocês já são amigos', style: ClippoText.label.copyWith(color: colors.accent)),
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

/// "Juntar com outra sessão" (D18): as sessões do mesmo jogo gravadas por outra
/// pessoa, em que eu também estou. O dono dela precisa aceitar.
class _MergeSessionScreen extends StatefulWidget {
  const _MergeSessionScreen({
    required this.into,
    required this.candidates,
    required this.pendingFromIds,
    required this.repository,
  });

  final Session into;
  final List<Session> candidates;

  /// Sessões para as quais já existe pedido meu esperando resposta.
  final Set<String> pendingFromIds;
  final SessionsRepository repository;

  @override
  State<_MergeSessionScreen> createState() => _MergeSessionScreenState();
}

class _MergeSessionScreenState extends State<_MergeSessionScreen> {
  String? _sendingId;
  String? _error;

  Future<void> _request(Session from) async {
    setState(() {
      _sendingId = from.id;
      _error = null;
    });
    try {
      await widget.repository.requestSessionMerge(intoSessionId: widget.into.id, fromSessionId: from.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingId = null;
        _error = SessionsFailure.from(e).message;
      });
    }
  }

  String? _ownerName(Session s) {
    for (final p in s.participants) {
      if (p.uid == s.ownerId) return p.firstName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final candidates = widget.candidates;

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Juntar',
            line2: 'sessões.',
            subtitle: 'Cada um gravou de um lado? Junte os lances em ${widget.into.name}. '
                'O dono da outra sessão precisa aceitar.',
          ),
          const SizedBox(height: ClippoSpace.section),
          if (_error != null) ...[
            Text(_error!, style: ClippoText.label.copyWith(color: colors.error)),
            const SizedBox(height: ClippoSpace.spaceM),
          ],
          if (candidates.isEmpty) ...[
            Text('Nenhuma sessão para juntar', style: ClippoText.titleS.copyWith(color: colors.text)),
            const SizedBox(height: ClippoSpace.spaceM),
            Text(
              'Aparecem aqui as sessões de outra pessoa em que você está, gravadas até '
              '$mergeToleranceMinutes min antes ou depois desta.',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            ),
          ],
          for (var i = 0; i < candidates.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _MergeCandidateTile(
              session: candidates[i],
              ownerName: _ownerName(candidates[i]),
              pending: widget.pendingFromIds.contains(candidates[i].id),
              sending: _sendingId == candidates[i].id,
              onTap: _sendingId == null ? () => _request(candidates[i]) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _MergeCandidateTile extends StatelessWidget {
  const _MergeCandidateTile({
    required this.session,
    required this.ownerName,
    required this.pending,
    required this.sending,
    required this.onTap,
  });

  final Session session;
  final String? ownerName;
  final bool pending;
  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final status = pending ? 'Esperando' : (sending ? 'Enviando…' : 'Pedir');
    return Semantics(
      button: !pending,
      label: '${session.name}, $status',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: pending ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ClippoSpace.cardPadding,
              vertical: ClippoSpace.fieldPaddingV,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.name, style: ClippoText.titleS.copyWith(color: colors.text)),
                      const SizedBox(height: ClippoSpace.labelToValue),
                      Text(
                        clippoDotList([
                          clippoTimeRange(session.startedAt, session.endedAt),
                          if (ownerName != null) 'de $ownerName',
                          clippoHighlightCount(session.highlightCount),
                        ]),
                        style: ClippoText.label.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ClippoSpace.spaceM),
                Text(status, style: ClippoText.label.copyWith(color: pending ? colors.textMuted : colors.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
