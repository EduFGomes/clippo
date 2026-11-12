import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/friends_repository.dart';
import 'package:clippo/core/data/friendship.dart';
import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/data/sessions_repository.dart';
import 'package:clippo/core/format/clippo_format.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_message.dart';
import 'package:clippo/core/widgets/clippo_pill_button.dart';
import 'package:clippo/core/widgets/clippo_pressable.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_session_card.dart';
import 'package:clippo/core/widgets/clippo_svg_icon.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// Amigos (docs/produto.md › 4.6): amigos aceitos, pedidos recebidos e enviados (R15),
/// "X sessões juntos" (R16) e o pedido de amizade pelo @ exato (D16).
///
/// Não existe entrada em sessão por código, link ou QR: quem participa é quem o dono
/// da sessão escolheu entre os amigos.
///
/// Tudo vem do [FriendsRepository] e do [SessionsRepository]. Nos testes e no
/// catálogo, injete [repository], [friendships], [sessions] e [myUid].
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({
    super.key,
    this.repository,
    this.friendships,
    this.sessions,
    this.myUid,
    this.onOpenSession,
  });

  /// Quem lê e grava as amizades. Padrão: o [friendsRepository] do app.
  final FriendsRepository? repository;

  /// Amizades e pedidos em tempo real. Padrão: `repository.watchFriendships()`.
  final Stream<List<Friendship>>? friendships;

  /// As minhas sessões, base do "X sessões juntos". Padrão: `watchMySessions()`.
  final Stream<SessionsSnapshot>? sessions;

  /// Uid de quem está logado. Padrão: o usuário do Firebase Auth.
  final String? myUid;

  /// Abre a tela Sessão. A casca de navegação (app_shell.dart) é quem conhece a
  /// feature Início: uma feature não importa outra (regra 3 do AGENTS.md).
  final ValueChanged<Session>? onOpenSession;

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

/// O que a tela sabe agora, compartilhado com o perfil do amigo e a busca pelo @.
@immutable
class _FriendsData {
  const _FriendsData({this.friendships, this.failure, this.sessions, this.sessionsOffline = false});

  /// Nulo enquanto carrega.
  final List<Friendship>? friendships;
  final FriendsFailure? failure;

  /// Nulo enquanto carrega ou quando não deu para ler as sessões.
  final List<Session>? sessions;
  final bool sessionsOffline;

  _FriendsData copyWith({
    List<Friendship>? friendships,
    FriendsFailure? failure,
    bool clearFailure = false,
    List<Session>? sessions,
    bool clearSessions = false,
    bool? sessionsOffline,
  }) => _FriendsData(
    friendships: friendships ?? this.friendships,
    failure: clearFailure ? null : (failure ?? this.failure),
    sessions: clearSessions ? null : (sessions ?? this.sessions),
    sessionsOffline: sessionsOffline ?? this.sessionsOffline,
  );

  Friendship? friendshipWith(String uid) {
    for (final f in friendships ?? const <Friendship>[]) {
      if (f.other.uid == uid) return f;
    }
    return null;
  }

  /// Nulo quando as sessões ainda não chegaram.
  int? sessionsTogether(String myUid, String friendUid) {
    final mine = sessions;
    if (mine == null) return null;
    return FriendsRepository.sessionsTogether(myUid, friendUid, mine);
  }

  List<Session> sharedSessions(String myUid, String friendUid) => (sessions ?? const <Session>[])
      .where((s) => !s.isMerged && s.includesBoth(myUid, friendUid))
      .toList(growable: false);
}

/// Mensagem curta embaixo da busca: o que acabou de acontecer.
class _Feedback {
  const _Feedback(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _searchController = TextEditingController();
  final _data = ValueNotifier<_FriendsData>(const _FriendsData());

  StreamSubscription<List<Friendship>>? _friendshipsSub;
  StreamSubscription<SessionsSnapshot>? _sessionsSub;

  /// Uids com uma ação em andamento (aceitar, recusar, cancelar, remover).
  final Set<String> _busy = <String>{};

  // Busca pelo @ exato direto na lista (sem abrir o "Convidar"). Só o @ exato: ninguém lista
  // users/ (D16), então nome de quem ainda não é amigo não dá para procurar.
  Timer? _lookupTimer;

  /// O @ procurado (normalizado), quem usa e se a resposta já chegou.
  String? _lookupQuery;
  Friend? _lookupFound;
  bool _lookupDone = false;
  bool _lookupFailed = false;

  late final String _myUid = widget.myUid ?? _signedInUid();

  FriendsRepository get _repository => widget.repository ?? friendsRepository;

  static String _signedInUid() {
    if (!isUserSignedIn) return '';
    return authRepository.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _subscribeFriendships();
    _sessionsSub = _resolveSessions().listen(
      (snapshot) => _data.value = _data.value.copyWith(
        sessions: snapshot.sessions,
        sessionsOffline: snapshot.fromCache,
      ),
      // Sem as sessões a lista continua útil; só não mostra o "X sessões juntos".
      onError: (Object _) => _data.value = _data.value.copyWith(clearSessions: true),
    );
  }

  @override
  void dispose() {
    _friendshipsSub?.cancel();
    _sessionsSub?.cancel();
    _data.dispose();
    _lookupTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<Friendship>> _resolveFriendships() {
    if (widget.friendships != null) return widget.friendships!;
    if (widget.repository != null || isUserSignedIn) return _repository.watchFriendships();
    return Stream<List<Friendship>>.error(
      const FriendsFailure('Entre na sua conta para ver seus amigos.'),
    );
  }

  Stream<SessionsSnapshot> _resolveSessions() {
    if (widget.sessions != null) return widget.sessions!;
    if (isUserSignedIn) return sessionsRepository.watchMySessions();
    return const Stream<SessionsSnapshot>.empty();
  }

  /// Liga (ou religa, no "Tentar de novo") a leitura das amizades em tempo real.
  void _subscribeFriendships() {
    _friendshipsSub?.cancel();
    _data.value = _FriendsData(
      sessions: _data.value.sessions,
      sessionsOffline: _data.value.sessionsOffline,
    );
    _friendshipsSub = _resolveFriendships().listen(
      (list) => _data.value = _data.value.copyWith(friendships: list, clearFailure: true),
      onError: (Object error) =>
          _data.value = _data.value.copyWith(failure: FriendsFailure.from(error)),
    );
  }

  /// O resultado de uma ação vai para o aviso do rodapé, como no resto do app (antes ficava
  /// no topo da lista, longe de onde a pessoa tocou).
  void _tell(String message) {
    if (mounted) showClippoMessage(context, message);
  }

  /// Roda uma ação do repositório marcando a pessoa como ocupada. true = deu certo.
  Future<bool> _run(String uid, Future<void> Function() action, String success) async {
    if (_busy.contains(uid)) return false;
    setState(() => _busy.add(uid));
    try {
      await action();
      _tell(success);
      return true;
    } catch (error) {
      _tell(FriendsFailure.from(error).message);
      return false;
    } finally {
      if (mounted) setState(() => _busy.remove(uid));
    }
  }

  Future<void> _accept(Friend person) => _run(
    person.uid,
    () => _repository.acceptFriendRequest(person.uid),
    'Agora você e ${person.firstName} são amigos.',
  );

  Future<void> _decline(Friend person) => _run(
    person.uid,
    () => _repository.removeFriend(person.uid),
    'Convite de ${person.firstName} recusado.',
  );

  Future<void> _cancel(Friend person) => _run(
    person.uid,
    () => _repository.removeFriend(person.uid),
    'Pedido para ${person.firstName} cancelado.',
  );

  /// Os amigos aceitos, em ordem de nome, que batem com [raw] (nome ou @). Vazio = todos.
  List<Friend> _matchingFriends(List<Friendship> list, String raw) {
    final text = raw.trim();
    final query = normalizeUsername(text);
    final friends = list.where((f) => f.isAccepted).map((f) => f.other).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (text.isEmpty) return friends;
    return friends
        .where((f) => f.name.toLowerCase().contains(text.toLowerCase()) || f.username.toLowerCase().contains(query))
        .toList();
  }

  /// O @ a procurar no Clippo para o que está digitado, ou nulo. Procura quando é um @ válido e
  /// a pessoa começou com "@" ou nenhum amigo bate com o texto ("brun" acha o Bruno e para aí).
  String? _lookupFor(String raw, List<Friend> matchingFriends) {
    final text = raw.trim();
    if (text.isEmpty || validateUsername(text) != null) return null;
    final username = normalizeUsername(text);
    if (matchingFriends.any((f) => f.username.toLowerCase() == username)) return null;
    if (!text.startsWith('@') && matchingFriends.isNotEmpty) return null;
    return username;
  }

  /// Espera a pessoa parar de digitar e lê `usernames/{@}` (uma leitura, como no "Convidar").
  void _scheduleLookup(String? username) {
    if (username == _lookupQuery) return;
    _lookupTimer?.cancel();
    setState(() {
      _lookupQuery = username;
      _lookupFound = null;
      _lookupDone = false;
      _lookupFailed = false;
    });
    if (username == null) return;
    _lookupTimer = Timer(ClippoMotion.searchDebounce, () async {
      try {
        final found = await _repository.findByUsername(username);
        if (!mounted || _lookupQuery != username) return;
        setState(() {
          _lookupFound = found == null || found.uid == _myUid ? null : found;
          _lookupDone = true;
        });
      } catch (_) {
        if (!mounted || _lookupQuery != username) return;
        setState(() {
          _lookupDone = true;
          _lookupFailed = true;
        });
      }
    });
  }

  /// Manda o pedido para quem a busca achou pelo @. Se a pessoa já tinha me pedido, viram
  /// amigos na hora (sendFriendRequest devolve `accepted`).
  Future<void> _addFound(Friend person) async {
    if (_busy.contains(person.uid)) return;
    setState(() => _busy.add(person.uid));
    try {
      final status = await _repository.sendFriendRequest(person.username);
      _tell(status == FriendshipStatus.accepted
          ? 'Agora você e ${person.firstName} são amigos.'
          : 'Pedido enviado para ${person.firstName}. Quando aceitar, vocês viram amigos.');
    } catch (error) {
      _tell(FriendsFailure.from(error).message);
    } finally {
      if (mounted) setState(() => _busy.remove(person.uid));
    }
  }

  /// Pergunta antes e desfaz a amizade. true = removeu.
  Future<bool> _confirmAndRemove(BuildContext sheetHost, Friend friend) async {
    final confirmed = await _confirmRemoval(sheetHost, friend);
    if (!confirmed || !mounted) return false;
    return _run(
      friend.uid,
      () => _repository.removeFriend(friend.uid),
      '${friend.firstName} saiu dos seus amigos.',
    );
  }

  Future<void> _openAddFriend({String initial = ''}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _AddFriendScreen(
          repository: _repository,
          data: _data,
          myUid: _myUid,
          initialUsername: initial,
        ),
      ),
    );
  }

  Future<void> _openFriendProfile(Friend friend) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => _FriendProfileScreen(
          friend: friend,
          data: _data,
          myUid: _myUid,
          onOpenSession: widget.onOpenSession,
          onRemove: () => _confirmAndRemove(routeContext, friend),
        ),
      ),
    );
  }

  Future<void> _showFriendOptions(Friend friend) async {
    final colors = ClippoColors.of(context);
    final together = _data.value.sessionsTogether(_myUid, friend.uid);
    final action = await showModalBottomSheet<_FriendMenuOption>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(ClippoSpace.cardPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(friend.name, style: ClippoText.titleS.copyWith(color: colors.text)),
                const SizedBox(height: ClippoSpace.labelToValue),
                Text(
                  clippoDotList([
                    '@${friend.username}',
                    if (together != null) clippoSharedSessionsCount(together),
                  ]),
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
      await _openFriendProfile(friend);
    } else {
      await _confirmAndRemove(context, friend);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TopHeader(onInvite: () => _openAddFriend()),
          const SizedBox(height: ClippoSpace.section),
          ValueListenableBuilder<_FriendsData>(
            valueListenable: _data,
            builder: (context, data, _) => _buildBody(data),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(_FriendsData data) {
    final list = data.friendships;
    if (list == null && data.failure != null) {
      return _Problem(failure: data.failure!, onRetry: _subscribeFriendships);
    }
    if (list == null) return const _Loading();

    final colors = ClippoColors.of(context);
    final raw = _searchController.text.trim();
    final query = normalizeUsername(raw);
    final friends = _matchingFriends(list, '');
    final incoming = list.where((f) => f.isIncomingFor(_myUid)).map((f) => f.other).toList();
    final outgoing = list.where((f) => f.isOutgoingFor(_myUid)).map((f) => f.other).toList();
    final filtered = _matchingFriends(list, raw);
    // O @ procurado no Clippo vale para o texto de agora (a resposta pode ser de antes).
    final lookup = _lookupQuery != null && _lookupQuery == _lookupFor(raw, filtered) ? _lookupQuery : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClippoTextField(
          label: 'Buscar entre seus amigos',
          hint: 'Nome ou @usuário',
          controller: _searchController,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (text) {
            setState(() {});
            _scheduleLookup(_lookupFor(text, _matchingFriends(list, text)));
          },
        ),
        if (data.failure != null) ...[
          // Já tinha uma lista e a leitura caiu: mostra o aviso e mantém o que tinha.
          const SizedBox(height: ClippoSpace.spaceM),
          _FeedbackLine(feedback: _Feedback(data.failure!.message, isError: true)),
        ],
        if (query.isEmpty && incoming.isNotEmpty) ...[
          const SizedBox(height: ClippoSpace.section),
          _SectionHeader(title: 'Convites recebidos', count: incoming.length, highlight: true),
          const SizedBox(height: ClippoSpace.spaceM),
          for (var i = 0; i < incoming.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _RequestTile.incoming(
              person: incoming[i],
              busy: _busy.contains(incoming[i].uid),
              onAccept: () => _accept(incoming[i]),
              onDecline: () => _decline(incoming[i]),
            ),
          ],
        ],
        if (query.isEmpty && outgoing.isNotEmpty) ...[
          const SizedBox(height: ClippoSpace.section),
          _SectionHeader(title: 'Pedidos enviados', count: outgoing.length),
          const SizedBox(height: ClippoSpace.spaceM),
          for (var i = 0; i < outgoing.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _RequestTile.outgoing(
              person: outgoing[i],
              busy: _busy.contains(outgoing[i].uid),
              onCancel: () => _cancel(outgoing[i]),
            ),
          ],
        ],
        const SizedBox(height: ClippoSpace.section),
        _SectionHeader(title: 'Seus amigos', count: filtered.length),
        const SizedBox(height: ClippoSpace.spaceM),
        if (friends.isEmpty && query.isEmpty) ...[
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
          ClippoPrimaryButton(label: 'Adicionar pelo @', onPressed: () => _openAddFriend()),
        ] else if (filtered.isEmpty) ...[
          Text('Nenhum amigo com "$raw"', style: ClippoText.titleS.copyWith(color: colors.text)),
          const SizedBox(height: ClippoSpace.spaceS),
          if (lookup == null) ...[
            const SizedBox(height: ClippoSpace.spaceS),
            Text(
              'Para achar alguém que ainda não é seu amigo, digite o @ exato.',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            ),
          ],
        ] else
          for (var i = 0; i < filtered.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            _FriendRowTile(
              friend: filtered[i],
              sessionsTogether: data.sessionsTogether(_myUid, filtered[i].uid),
              onTap: () => _openFriendProfile(filtered[i]),
              onMore: () => _showFriendOptions(filtered[i]),
            ),
          ],
        if (lookup != null) ...[
          const SizedBox(height: ClippoSpace.section),
          _SectionHeader(title: 'No Clippo', count: _lookupFound == null ? 0 : 1),
          const SizedBox(height: ClippoSpace.spaceM),
          _lookupResult(lookup, list, colors),
        ],
      ],
    );
  }

  /// Quem usa o @ procurado, com a ação certa para a situação de vocês dois.
  Widget _lookupResult(String username, List<Friendship> list, ClippoColors colors) {
    final found = _lookupFound;
    if (!_lookupDone) {
      return Semantics(
        liveRegion: true,
        child: Text('Procurando @$username…', style: ClippoText.body.copyWith(color: colors.textMuted)),
      );
    }
    if (_lookupFailed) {
      return Text(
        'Não deu para procurar agora. Confira a internet e tente de novo.',
        style: ClippoText.body.copyWith(color: colors.textMuted),
      );
    }
    if (found == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Ninguém usa @$username', style: ClippoText.titleS.copyWith(color: colors.text)),
          const SizedBox(height: ClippoSpace.spaceS),
          Text(
            'Confira o @ com a pessoa ou mande o link para ela baixar o app.',
            style: ClippoText.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: 'Mandar o link para baixar',
            onPressed: () => _openAddFriend(initial: username),
          ),
        ],
      );
    }
    Friendship? existing;
    for (final f in list) {
      if (f.other.uid == found.uid) existing = f;
    }
    final busy = _busy.contains(found.uid);
    if (existing != null && existing.isIncomingFor(_myUid)) {
      return _RequestTile.incoming(
        person: found,
        busy: busy,
        onAccept: () => _accept(found),
        onDecline: () => _decline(found),
      );
    }
    if (existing != null && existing.isOutgoingFor(_myUid)) {
      return _RequestTile.outgoing(person: found, busy: busy, onCancel: () => _cancel(found));
    }
    return _FoundPersonTile(person: found, busy: busy, onAdd: () => _addFound(found));
  }
}

/// Alguém que a busca achou pelo @ e ainda não é amigo: nome, @ e "Adicionar".
class _FoundPersonTile extends StatelessWidget {
  const _FoundPersonTile({required this.person, required this.busy, required this.onAdd});

  final Friend person;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.cardPadding),
        child: Row(
          children: [
            ClippoAvatar(name: person.name, photoUrl: person.photoUrl, size: ClippoSize.avatarLarge),
            const SizedBox(width: ClippoSpace.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text('@${person.username}', style: ClippoText.label.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceS),
            _Pill(
              label: busy ? 'Enviando…' : 'Adicionar',
              icon: busy ? null : 'plus',
              semanticsLabel: 'Adicionar amigo ${person.name}',
              onTap: busy ? null : onAdd,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pergunta antes de desfazer a amizade (removeFriend apaga o documento).
Future<bool> _confirmRemoval(BuildContext context, Friend friend) async {
  final colors = ClippoColors.of(context);
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.cardPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Remover ${friend.firstName} dos amigos?',
              style: ClippoText.titleS.copyWith(color: colors.text),
            ),
            const SizedBox(height: ClippoSpace.spaceS),
            Text(
              'As sessões que vocês já gravaram continuam lá. Para gravar juntos de novo, '
              'um manda outro pedido pelo @.',
              style: ClippoText.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: ClippoSpace.spaceL),
            ClippoPrimaryButton.danger(
              label: 'Remover',
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: ClippoSpace.spaceS),
            ClippoTextButton(
              label: 'Manter amigo',
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.onInvite});

  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: ClippoScreenTitle(line1: 'Seus', line2: 'amigos.'),
        ),
        const SizedBox(width: ClippoSpace.spaceM),
        ClippoPillButton(
          label: 'Convidar',
          icon: 'plus',
          semanticLabel: 'Convidar amigo',
          onPressed: onInvite,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, this.highlight = false});

  final String title;
  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: ClippoText.titleS.copyWith(color: colors.text)),
        ),
        Text(
          '$count',
          style: ClippoText.label.copyWith(
            color: highlight ? colors.accent : colors.textMuted,
            fontFeatures: ClippoText.tabular,
          ),
        ),
      ],
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({required this.feedback});

  final _Feedback feedback;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final color = feedback.isError ? colors.error : colors.accent;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          ClippoSvgIcon(
            feedback.isError ? 'close' : 'check',
            size: ClippoSize.checkIcon,
            color: color,
          ),
          const SizedBox(width: ClippoSpace.spaceS),
          Expanded(
            child: Text(feedback.message, style: ClippoText.label.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      label: 'Carregando seus amigos',
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

/// Não deu para mostrar a lista: sem internet, conta expirada, erro nosso.
class _Problem extends StatelessWidget {
  const _Problem({required this.failure, required this.onRetry});

  final FriendsFailure failure;
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

/// Pílula de ação das linhas (Aceitar, Cancelar, Adicionar).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  final String label;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final bool filled;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final enabled = onTap != null;
    final foreground = filled ? colors.onPrimary : (enabled ? colors.accent : colors.textMuted);
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: ClippoPressable(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ClippoSize.minTouchTarget),
            child: Center(
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled
                      ? (enabled ? colors.primary : colors.controlSoft)
                      : (enabled ? colors.accentSoft : colors.controlSoft),
                  borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                  border: filled || !enabled
                      ? null
                      : Border.all(color: colors.accent, width: ClippoSize.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ClippoSpace.spaceM,
                    vertical: ClippoSpace.spaceS,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        ClippoSvgIcon(icon!, size: ClippoSize.checkIcon, color: foreground),
                        const SizedBox(width: ClippoSpace.spaceXs),
                      ],
                      Text(label, style: ClippoText.label.copyWith(color: foreground)),
                    ],
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

/// Pedido de amizade: recebido (Recusar ✕ / Aceitar) ou enviado (Cancelar).
class _RequestTile extends StatelessWidget {
  const _RequestTile.incoming({
    required this.person,
    required this.busy,
    required VoidCallback this.onAccept,
    required VoidCallback this.onDecline,
  }) : onCancel = null,
       incoming = true;

  const _RequestTile.outgoing({
    required this.person,
    required this.busy,
    required VoidCallback this.onCancel,
  }) : onAccept = null,
       onDecline = null,
       incoming = false;

  final Friend person;
  final bool busy;
  final bool incoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    // Ações embaixo do texto, não ao lado: com nome, @ e dois botões na mesma linha, o texto
    // ficava cortado ("@mariahalabi04 · e…") num celular comum.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(color: colors.outline, width: ClippoSize.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(ClippoSpace.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ClippoText.titleS.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: ClippoSpace.labelToValue),
                      Text(
                        incoming
                            ? '@${person.username} · quer jogar com você'
                            : '@${person.username} · esperando aceitar',
                        style: ClippoText.label.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: ClippoSpace.spaceS),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: ClippoSpace.spaceM,
              children: incoming
                  ? [
                      _Pill(
                        label: 'Recusar',
                        semanticsLabel: 'Recusar convite de ${person.name}',
                        onTap: busy ? null : onDecline,
                      ),
                      _Pill(
                        label: 'Aceitar',
                        semanticsLabel: 'Aceitar convite de ${person.name}',
                        filled: true,
                        onTap: busy ? null : onAccept,
                      ),
                    ]
                  : [
                      _Pill(
                        label: 'Cancelar',
                        semanticsLabel: 'Cancelar pedido para ${person.name}',
                        onTap: busy ? null : onCancel,
                      ),
                    ],
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
    required this.sessionsTogether,
    required this.onTap,
    required this.onMore,
  });

  final Friend friend;

  /// Nulo enquanto as sessões não chegaram.
  final int? sessionsTogether;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final secondary = clippoDotList([
      '@${friend.username}',
      if (sessionsTogether != null) clippoSharedSessionsCount(sessionsTogether!),
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
                child: ClippoPressable(
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

enum _FriendMenuOption { viewProfile, remove }

/// "Convidar": procura alguém pelo @ exato e manda o pedido de amizade (R15, D16).
/// A busca nunca lista usuários; quem ainda não tem o app recebe o link para baixar.
class _AddFriendScreen extends StatefulWidget {
  const _AddFriendScreen({
    required this.repository,
    required this.data,
    required this.myUid,
    this.initialUsername = '',
  });

  final FriendsRepository repository;
  final ValueListenable<_FriendsData> data;
  final String myUid;
  final String initialUsername;

  @override
  State<_AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<_AddFriendScreen> {
  static const String _downloadAppLink = 'https://clippo.app/baixar';

  late final _controller = TextEditingController(text: widget.initialUsername);

  String? _fieldError;
  bool _searching = false;
  bool _sending = false;
  bool _copiedLink = false;

  /// O @ procurado e quem usa. [_found] nulo depois de procurar = ninguém usa.
  String? _searched;
  Friend? _found;
  _Feedback? _feedback;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final raw = _controller.text;
    final error = validateUsername(raw);
    setState(() {
      _fieldError = error;
      _feedback = null;
      _searched = null;
      _found = null;
    });
    if (error != null) return;

    setState(() => _searching = true);
    try {
      final found = await widget.repository.findByUsername(raw);
      if (!mounted) return;
      setState(() {
        _searched = normalizeUsername(raw);
        _found = found;
      });
    } catch (e) {
      if (!mounted) return;
      final failure = FriendsFailure.from(e);
      setState(() {
        if (failure.code == 'username') {
          _fieldError = failure.message;
        } else {
          _feedback = _Feedback(failure.message, isError: true);
        }
      });
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(Friend person) async {
    setState(() {
      _sending = true;
      _feedback = null;
    });
    try {
      final status = await widget.repository.sendFriendRequest(person.username);
      if (!mounted) return;
      setState(() {
        _feedback = _Feedback(
          status == FriendshipStatus.accepted
              ? 'Agora você e ${person.firstName} são amigos.'
              : 'Pedido enviado para ${person.firstName}. Quando aceitar, vocês viram amigos.',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _feedback = _Feedback(FriendsFailure.from(e).message, isError: true));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copyDownloadLink() async {
    await Clipboard.setData(const ClipboardData(text: _downloadAppLink));
    if (!mounted) return;
    setState(() => _copiedLink = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(label: 'Amigos'),
          const SizedBox(height: ClippoSpace.section),
          const ClippoScreenTitle(
            line1: 'Adicionar',
            line2: 'amigo.',
            subtitle:
                'Digite o @ exato de quem joga com você. A pessoa aceita e vocês viram amigos.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: '@ do amigo',
            hint: 'rafa.costa',
            prefixText: '@',
            controller: _controller,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            errorText: _fieldError,
            onChanged: (_) {
              if (_fieldError != null) setState(() => _fieldError = null);
            },
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoPrimaryButton(label: 'Procurar', loading: _searching, onPressed: _search),
          if (_searched != null) ...[
            const SizedBox(height: ClippoSpace.section),
            if (_found == null)
              Text(
                'Ninguém usa @$_searched no Clippo. Confira o @ ou mande o link abaixo.',
                style: ClippoText.body.copyWith(color: colors.textMuted),
              )
            else
              ValueListenableBuilder<_FriendsData>(
                valueListenable: widget.data,
                builder: (context, data, _) => _FoundTile(
                  person: _found!,
                  isMe: _found!.uid == widget.myUid,
                  friendship: data.friendshipWith(_found!.uid),
                  myUid: widget.myUid,
                  busy: _sending,
                  onAdd: () => _add(_found!),
                ),
              ),
          ],
          if (_feedback != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            _FeedbackLine(feedback: _feedback!),
          ],
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
                    'Ainda não tem o Clippo?',
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.spaceS),
                  Text(
                    'Mande o link para baixar o app. Com a conta criada, é só procurar o @.',
                    style: ClippoText.body.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(_downloadAppLink, style: ClippoText.label.copyWith(color: colors.accent)),
                  const SizedBox(height: ClippoSpace.spaceM),
                  ClippoTextButton(
                    label: _copiedLink ? 'Link copiado!' : 'Copiar link para baixar o app',
                    onPressed: _copyDownloadLink,
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

/// Quem usa o @ procurado, com o que dá para fazer agora.
class _FoundTile extends StatelessWidget {
  const _FoundTile({
    required this.person,
    required this.isMe,
    required this.friendship,
    required this.myUid,
    required this.busy,
    required this.onAdd,
  });

  final Friend person;
  final bool isMe;
  final Friendship? friendship;
  final String myUid;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final f = friendship;

    final Widget trailing;
    if (isMe) {
      trailing = Text('É você', style: ClippoText.label.copyWith(color: colors.textMuted));
    } else if (f != null && f.isAccepted) {
      trailing = Text('Amigos', style: ClippoText.label.copyWith(color: colors.accent));
    } else if (f != null && f.isOutgoingFor(myUid)) {
      trailing = Text('Pedido enviado', style: ClippoText.label.copyWith(color: colors.accent));
    } else {
      // Pedido recebido também passa por aqui: sendFriendRequest aceita na hora.
      trailing = _Pill(
        label: f != null && f.isIncomingFor(myUid) ? 'Aceitar' : 'Adicionar',
        semanticsLabel: 'Adicionar amigo ${person.name}',
        icon: 'plus',
        onTap: busy ? null : onAdd,
      );
    }

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
                    '@${person.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClippoText.label.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: ClippoSpace.spaceS),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Perfil de um amigo: quem é e as sessões que vocês gravaram juntos (R16).
class _FriendProfileScreen extends StatefulWidget {
  const _FriendProfileScreen({
    required this.friend,
    required this.data,
    required this.myUid,
    required this.onRemove,
    this.onOpenSession,
  });

  final Friend friend;
  final ValueListenable<_FriendsData> data;
  final String myUid;

  /// Pergunta e remove; true quando removeu.
  final Future<bool> Function() onRemove;
  final ValueChanged<Session>? onOpenSession;

  @override
  State<_FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<_FriendProfileScreen> {
  String? _openId;
  bool _touchedACard = false;
  bool _removing = false;

  Future<void> _remove() async {
    setState(() => _removing = true);
    final removed = await widget.onRemove();
    if (!mounted) return;
    setState(() => _removing = false);
    if (removed) Navigator.of(context).pop();
  }

  bool _isOpen(Session session, int index) => _touchedACard ? _openId == session.id : index == 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_FriendsData>(
      valueListenable: widget.data,
      builder: (context, data, _) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, _FriendsData data) {
    final colors = ClippoColors.of(context);
    final friend = widget.friend;
    final isFriend = data.friendshipWith(friend.uid)?.isAccepted ?? false;
    final shared = data.sharedSessions(widget.myUid, friend.uid);
    final together = data.sessionsTogether(widget.myUid, friend.uid);

    final Widget sessionsBody;
    if (data.sessions == null) {
      sessionsBody = Text(
        'Não deu para carregar as sessões agora.',
        style: ClippoText.body.copyWith(color: colors.textMuted),
      );
    } else if (shared.isEmpty && data.sessionsOffline) {
      sessionsBody = Text(
        'Sem internet. As sessões de vocês aparecem assim que você conectar.',
        style: ClippoText.body.copyWith(color: colors.textMuted),
      );
    } else if (shared.isEmpty) {
      sessionsBody = Text(
        'Vocês ainda não gravaram nenhuma sessão juntos.',
        style: ClippoText.body.copyWith(color: colors.textMuted),
      );
    } else {
      sessionsBody = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shared.length; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.cardGap),
            ClippoSessionCard(
              title: shared[i].name,
              summary: clippoDotList([
                clippoDate(shared[i].startedAt),
                clippoHighlightCount(shared[i].highlightCount),
              ]),
              location: shared[i].location?.label,
              details: clippoDotList([
                clippoDuration(shared[i].duration),
                clippoParticipantCount(shared[i].participantCount),
              ]),
              participants: [
                for (final p in shared[i].visibleParticipants())
                  ClippoAvatarPerson(name: p.name, photoUrl: p.photoUrl),
              ],
              hiddenParticipants: shared[i].hiddenParticipantCount(),
              expanded: _isOpen(shared[i], i),
              onToggle: () => setState(() {
                _touchedACard = true;
                _openId = _isOpen(shared[i], i) ? null : shared[i].id;
              }),
              onAction: widget.onOpenSession == null
                  ? null
                  : () => widget.onOpenSession!(shared[i]),
            ),
          ],
        ],
      );
    }

    return ClippoScreenGround(
      footer: isFriend
          ? ClippoTextButton(label: 'Remover dos amigos', onPressed: _removing ? null : _remove)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(label: 'Amigos'),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: 'Perfil de',
            line2: '${friend.firstName}.',
            subtitle: together == null ? null : clippoSharedSessionsCount(together),
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
                    name: friend.name,
                    photoUrl: friend.photoUrl,
                    size: ClippoSize.avatarProfile,
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Text(
                    friend.name,
                    textAlign: TextAlign.center,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  const SizedBox(height: ClippoSpace.labelToValue),
                  Text(
                    '@${friend.username}',
                    textAlign: TextAlign.center,
                    style: ClippoText.label.copyWith(color: colors.accent),
                  ),
                  const SizedBox(height: ClippoSpace.spaceM),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isFriend) ...[
                        ClippoSvgIcon('check', size: ClippoSize.checkIcon, color: colors.accent),
                        const SizedBox(width: ClippoSpace.spaceXs),
                      ],
                      Text(
                        isFriend ? 'Vocês são amigos' : 'Vocês não são mais amigos',
                        style: ClippoText.label.copyWith(
                          color: isFriend ? colors.accent : colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: ClippoSpace.section),
          _SectionHeader(title: 'Sessões juntos', count: shared.length),
          const SizedBox(height: ClippoSpace.spaceM),
          sessionsBody,
        ],
      ),
    );
  }
}
