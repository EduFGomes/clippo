import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_pill_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// Modelo de Usuário para pesquisa.
class SearchUserItem {
  const SearchUserItem({
    required this.uid,
    required this.name,
    required this.username,
    this.avatarUrl,
    this.mutualFriends = 0,
    this.isFriend = false,
  });

  final String uid;
  final String name;
  final String username;
  final String? avatarUrl;
  final int mutualFriends;
  final bool isFriend;

  factory SearchUserItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SearchUserItem(
      uid: doc.id,
      name: data['name'] as String? ?? 'Usuário',
      username: data['username'] as String? ?? '',
      avatarUrl: data['photoUrl'] as String?,
      mutualFriends: (data['friendCount'] as num?)?.toInt() ?? 0,
      isFriend: false,
    );
  }
}

/// Modelo de Sessão para pesquisa.
class SearchSessionItem {
  const SearchSessionItem({
    required this.id,
    required this.title,
    required this.sport,
    required this.location,
    required this.ownerName,
    required this.highlightsCount,
    required this.isParticipant, // Tem check
    required this.isOpen, // Aberta para entrar ou fechada
    this.hasRequested = false,
  });

  final String id;
  final String title;
  final String sport;
  final String location;
  final String ownerName;
  final int highlightsCount;
  final bool isParticipant;
  final bool isOpen;
  final bool hasRequested;

  factory SearchSessionItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final data = doc.data() ?? {};
    final participantIds = List<String>.from(data['participantIds'] as List? ?? []);
    final isParticipant = participantIds.contains(currentUid) || (data['ownerId'] == currentUid);
    final isOpen = data['isOpen'] as bool? ?? false;

    return SearchSessionItem(
      id: doc.id,
      title: data['title'] as String? ?? 'Sessão sem título',
      sport: data['sport'] as String? ?? 'Geral',
      location: data['location'] as String? ?? 'Local não informado',
      ownerName: data['ownerName'] as String? ?? 'Organizador',
      highlightsCount: (data['highlightCount'] as num?)?.toInt() ?? 0,
      isParticipant: isParticipant,
      isOpen: isOpen,
    );
  }
}

/// Tela de Pesquisa:
/// - Permite pesquisar usuários e sessões diretamente no Firestore
/// - Sessões onde está inserido exibem um check indicador
/// - Sessões abertas permitem entrar diretamente
/// - Sessões fechadas permitem solicitar entrada
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.onOpenSession,
    this.onOpenUserProfile,
  });

  final void Function(Session session)? onOpenSession;
  final void Function(String uid)? onOpenUserProfile;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  int _selectedFilter = 0; // 0 = Todos, 1 = Sessões, 2 = Usuários
  final Set<String> _requestedSessions = {};
  final Set<String> _joinedSessions = {};

  bool _isLoading = false;
  List<SearchUserItem> _firestoreUsers = [];
  List<SearchSessionItem> _firestoreSessions = [];

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onSearchChanged);
    _performFirestoreSearch('');
  }

  @override
  void dispose() {
    _queryController.removeListener(_onSearchChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _performFirestoreSearch(_queryController.text.trim());
  }

  Future<void> _performFirestoreSearch(String query) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    setState(() => _isLoading = true);

    try {
      final userQuery = query.toLowerCase();

      // Busca usuários
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .limit(30)
          .get();

      final users = usersSnap.docs
          .map((d) => SearchUserItem.fromFirestore(d))
          .where((u) {
            if (u.uid == currentUid) return false;
            if (userQuery.isEmpty) return true;
            return u.name.toLowerCase().contains(userQuery) ||
                u.username.toLowerCase().contains(userQuery);
          })
          .toList();

      // Busca sessões (abertas ou onde é participante)
      final sessionsSnap = await FirebaseFirestore.instance
          .collection('sessions')
          .limit(30)
          .get();

      final sessions = sessionsSnap.docs
          .map((d) => SearchSessionItem.fromFirestore(d, currentUid))
          .where((s) {
            if (userQuery.isEmpty) return true;
            return s.title.toLowerCase().contains(userQuery) ||
                s.sport.toLowerCase().contains(userQuery) ||
                s.location.toLowerCase().contains(userQuery);
          })
          .toList();

      if (mounted) {
        setState(() {
          _firestoreUsers = users;
          _firestoreSessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleJoinSession(SearchSessionItem session) {
    setState(() {
      _joinedSessions.add(session.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Você entrou na sessão "${session.title}"!')),
    );
  }

  void _handleRequestSession(SearchSessionItem session) {
    setState(() {
      _requestedSessions.add(session.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Solicitação de entrada enviada para ${session.ownerName}!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    final showSessions = _selectedFilter == 0 || _selectedFilter == 1;
    final showUsers = _selectedFilter == 0 || _selectedFilter == 2;

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoScreenTitle(line1: 'Buscar', line2: 'no Clippo.'),
          const SizedBox(height: ClippoSpace.spaceL),
          ClippoTextField(
            controller: _queryController,
            label: 'Pesquisar',
            hint: 'Buscar amigos, times ou sessões...',
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          // Filtros
          Row(
            children: [
              _FilterChip(
                label: 'Todos',
                selected: _selectedFilter == 0,
                onTap: () => setState(() => _selectedFilter = 0),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              _FilterChip(
                label: 'Sessões',
                selected: _selectedFilter == 1,
                onTap: () => setState(() => _selectedFilter = 1),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              _FilterChip(
                label: 'Usuários',
                selected: _selectedFilter == 2,
                onTap: () => setState(() => _selectedFilter = 2),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceL),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_firestoreSessions.isEmpty && _firestoreUsers.isEmpty)
                    ? Center(
                        child: Text(
                          'Nenhum resultado encontrado.',
                          style: ClippoText.body.copyWith(color: colors.textMuted),
                        ),
                      )
                    : ListView(
                        children: [
                          if (showSessions && _firestoreSessions.isNotEmpty) ...[
                            Text(
                              'Sessões (${_firestoreSessions.length})',
                              style: ClippoText.titleS.copyWith(color: colors.text),
                            ),
                            const SizedBox(height: ClippoSpace.spaceS),
                            for (final session in _firestoreSessions)
                              _SessionSearchCard(
                                session: session,
                                isJoined: _joinedSessions.contains(session.id),
                                isRequested: _requestedSessions.contains(session.id),
                                onJoin: () => _handleJoinSession(session),
                                onRequest: () => _handleRequestSession(session),
                              ),
                            const SizedBox(height: ClippoSpace.spaceL),
                          ],
                          if (showUsers && _firestoreUsers.isNotEmpty) ...[
                            Text(
                              'Usuários (${_firestoreUsers.length})',
                              style: ClippoText.titleS.copyWith(color: colors.text),
                            ),
                            const SizedBox(height: ClippoSpace.spaceS),
                            for (final user in _firestoreUsers)
                              _UserSearchCard(
                                user: user,
                                onTap: () => widget.onOpenUserProfile?.call(user.uid),
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: ClippoSpace.spaceM,
          vertical: ClippoSpace.spaceS,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
          border: Border.all(color: selected ? colors.primary : colors.line),
        ),
        child: Text(
          label,
          style: ClippoText.label.copyWith(
            color: selected ? colors.onPrimary : colors.text,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _SessionSearchCard extends StatelessWidget {
  const _SessionSearchCard({
    required this.session,
    required this.isJoined,
    required this.isRequested,
    required this.onJoin,
    required this.onRequest,
  });

  final SearchSessionItem session;
  final bool isJoined;
  final bool isRequested;
  final VoidCallback onJoin;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final hasCheck = session.isParticipant || isJoined;

    return Container(
      margin: const EdgeInsets.only(bottom: ClippoSpace.spaceM),
      padding: const EdgeInsets.all(ClippoSpace.spaceM),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(
          color: hasCheck ? colors.primary.withValues(alpha: 0.5) : colors.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasCheck
                  ? colors.primary.withValues(alpha: 0.15)
                  : colors.controlSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasCheck ? Icons.check_circle_rounded : Icons.sports_basketball_rounded,
              color: hasCheck ? colors.primary : colors.textMuted,
            ),
          ),
          const SizedBox(width: ClippoSpace.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: ClippoText.titleS.copyWith(color: colors.text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasCheck)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ClippoSpace.spaceS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: colors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Você participa',
                              style: ClippoText.label.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                Text(
                  '${session.sport} · ${session.location}',
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
                Text(
                  'Por ${session.ownerName} · ${session.highlightsCount} lances',
                  style: ClippoText.label.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: ClippoSpace.spaceS),
          if (!hasCheck) ...[
            if (session.isOpen)
              ClippoPillButton(
                label: 'Entrar',
                icon: 'plus',
                onPressed: onJoin,
              )
            else if (isRequested)
              Text(
                'Solicitado',
                style: ClippoText.label.copyWith(color: colors.textMuted),
              )
            else
              ClippoPillButton(
                label: 'Pedir',
                icon: 'plus',
                onPressed: onRequest,
              ),
          ],
        ],
      ),
    );
  }
}

class _UserSearchCard extends StatelessWidget {
  const _UserSearchCard({
    required this.user,
    required this.onTap,
  });

  final SearchUserItem user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      child: Container(
        margin: const EdgeInsets.only(bottom: ClippoSpace.spaceM),
        padding: const EdgeInsets.all(ClippoSpace.spaceM),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
          border: Border.all(color: colors.line),
        ),
        child: Row(
          children: [
            ClippoAvatar(
              name: user.name,
              photoUrl: user.avatarUrl,
              size: 44,
            ),
            const SizedBox(width: ClippoSpace.spaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: ClippoText.titleS.copyWith(color: colors.text),
                  ),
                  Text(
                    '@${user.username}',
                    style: ClippoText.body.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
