import 'package:flutter/material.dart';

import 'package:clippo/core/data/session.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_message.dart';
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
}

/// Tela de Pesquisa:
/// - Permite pesquisar usuários e sessões
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

  static final List<SearchUserItem> _demoUsers = [
    const SearchUserItem(uid: 'u1', name: 'Rafaela Santos', username: 'rafa_santos', mutualFriends: 4, isFriend: true),
    const SearchUserItem(uid: 'u2', name: 'Eduardo Gomes', username: 'edugomes', mutualFriends: 7, isFriend: true),
    const SearchUserItem(uid: 'u3', name: 'Bia Oliveira', username: 'bia_oli', mutualFriends: 2, isFriend: false),
    const SearchUserItem(uid: 'u4', name: 'Lucas Silva', username: 'lucassilva', mutualFriends: 5, isFriend: false),
    const SearchUserItem(uid: 'u5', name: 'Gabriel P.', username: 'gabriel_fut', mutualFriends: 1, isFriend: false),
  ];

  static final List<SearchSessionItem> _demoSessions = [
    const SearchSessionItem(
      id: 's1',
      title: 'Rachão de Quinta',
      sport: 'Basquete',
      location: 'Parque Ibirapuera',
      ownerName: 'Eduardo Gomes',
      highlightsCount: 14,
      isParticipant: true, // Já inserido com check
      isOpen: false,
    ),
    const SearchSessionItem(
      id: 's2',
      title: 'Pelada de Sábado',
      sport: 'Futebol',
      location: 'Arena Soccer Point',
      ownerName: 'Lucas Silva',
      highlightsCount: 8,
      isParticipant: false,
      isOpen: true, // Aberta para entrar
    ),
    const SearchSessionItem(
      id: 's3',
      title: 'Treino de Salto e Enterradas',
      sport: 'Basquete',
      location: 'Quadra Central',
      ownerName: 'Gabriel P.',
      highlightsCount: 5,
      isParticipant: false,
      isOpen: false, // Fechada - solicitar
    ),
    const SearchSessionItem(
      id: 's4',
      title: 'Vôlei de Areia Domingo',
      sport: 'Vôlei',
      location: 'Praça das Corujas',
      ownerName: 'Rafaela Santos',
      highlightsCount: 19,
      isParticipant: true, // Já inserido com check
      isOpen: true,
    ),
  ];

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final q = _queryController.text.trim().toLowerCase();

    final filteredUsers = _demoUsers.where((u) {
      if (_selectedFilter == 1) return false; // só sessões
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) || u.username.toLowerCase().contains(q);
    }).toList();

    final filteredSessions = _demoSessions.where((s) {
      if (_selectedFilter == 2) return false; // só usuários
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.sport.toLowerCase().contains(q) ||
          s.location.toLowerCase().contains(q) ||
          s.ownerName.toLowerCase().contains(q);
    }).toList();

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoScreenTitle(line1: 'Explorar e', line2: 'pesquisar.'),
          const SizedBox(height: ClippoSpace.spaceM),

          // Campo de busca com ícone de lupa
          ClippoTextField(
            controller: _queryController,
            label: 'Buscar usuários ou sessões',
            hint: 'Ex: nome, @usuário, esporte, quadra…',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          // Filtros
          Row(
            children: [
              _filterChip('Todos', 0),
              const SizedBox(width: ClippoSpace.spaceS),
              _filterChip('Sessões', 1),
              const SizedBox(width: ClippoSpace.spaceS),
              _filterChip('Usuários', 2),
            ],
          ),
          const SizedBox(height: ClippoSpace.section),

          // Sessões
          if (_selectedFilter != 2 && filteredSessions.isNotEmpty) ...[
            Text('SESSÕES', style: ClippoText.label.copyWith(color: colors.textLabel)),
            const SizedBox(height: ClippoSpace.spaceS),
            for (final session in filteredSessions) ...[
              _buildSessionCard(session, colors),
              const SizedBox(height: ClippoSpace.spaceM),
            ],
            const SizedBox(height: ClippoSpace.spaceM),
          ],

          // Usuários
          if (_selectedFilter != 1 && filteredUsers.isNotEmpty) ...[
            Text('USUÁRIOS', style: ClippoText.label.copyWith(color: colors.textLabel)),
            const SizedBox(height: ClippoSpace.spaceS),
            for (final user in filteredUsers) ...[
              _buildUserCard(user, colors),
              const SizedBox(height: ClippoSpace.spaceM),
            ],
          ],

          if (filteredSessions.isEmpty && filteredUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhum resultado encontrado para "$q".',
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final colors = ClippoColors.of(context);
    final active = _selectedFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
          border: Border.all(color: active ? colors.primary : colors.line),
        ),
        child: Text(
          label,
          style: ClippoText.label.copyWith(
            color: active ? colors.onPrimary : colors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSessionCard(SearchSessionItem item, ClippoColors colors) {
    final isParticipant = item.isParticipant || _joinedSessions.contains(item.id);
    final isRequested = item.hasRequested || _requestedSessions.contains(item.id);

    return Container(
      padding: const EdgeInsets.all(ClippoSpace.spaceM),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(color: colors.line),
      ),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: ClippoText.titleS.copyWith(color: colors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isParticipant) ...[
                          const SizedBox(width: ClippoSpace.spaceS),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 14, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  'Inserido',
                                  style: ClippoText.label.copyWith(
                                    color: colors.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: ClippoSpace.labelToValue),
                    Text(
                      '${item.sport} • ${item.location}',
                      style: ClippoText.body.copyWith(color: colors.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: ClippoSpace.spaceS),
              Text(
                '${item.highlightsCount} lances',
                style: ClippoText.label.copyWith(color: colors.textLabel, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Row(
            children: [
              Text(
                'Criada por ${item.ownerName}',
                style: ClippoText.body.copyWith(color: colors.textMuted, fontSize: 13),
              ),
              const Spacer(),
              if (isParticipant)
                ClippoPillButton(
                  label: 'Ver sessão',
                  icon: 'play',
                  onPressed: () {
                    showClippoMessage(context, 'Abrindo "${item.title}"…');
                  },
                )
              else if (item.isOpen)
                ClippoPillButton(
                  label: 'Entrar na sessão',
                  icon: 'plus',
                  onPressed: () {
                    setState(() => _joinedSessions.add(item.id));
                    showClippoMessage(context, 'Você entrou na sessão "${item.title}"!');
                  },
                )
              else if (isRequested)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(ClippoRadius.radiusPill),
                    border: Border.all(color: colors.line),
                  ),
                  child: Text(
                    'Solicitação enviada',
                    style: ClippoText.body.copyWith(color: colors.textMuted, fontSize: 13),
                  ),
                )
              else
                ClippoPillButton(
                  label: 'Pedir solicitação',
                  icon: 'tripod',
                  onPressed: () {
                    setState(() => _requestedSessions.add(item.id));
                    showClippoMessage(context, 'Solicitação enviada para ${item.ownerName}.');
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(SearchUserItem user, ClippoColors colors) {
    return Container(
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
                Text(user.name, style: ClippoText.label.copyWith(color: colors.text)),
                const SizedBox(height: ClippoSpace.labelToValue),
                Text(
                  '@${user.username} • ${user.mutualFriends} amigos em comum',
                  style: ClippoText.body.copyWith(color: colors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          if (user.isFriend)
            Icon(Icons.check, size: 20, color: colors.primary)
          else
            ClippoPillButton(
              label: 'Conectar',
              icon: 'friends',
              onPressed: () {
                showClippoMessage(context, 'Pedido enviado para @${user.username}.');
              },
            ),
        ],
      ),
    );
  }
}
