import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_avatar.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';

/// Modelo de notificação do Clippo.
class ClippoNotification {
  const ClippoNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.avatarUrl,
    this.initials,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? avatarUrl;
  final String? initials;
  final bool read;
}

/// Tela de notificações em ordem cronológica (mais recente pro mais antigo).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    this.notifications,
  });

  final List<ClippoNotification>? notifications;

  static List<ClippoNotification> get defaultNotifications {
    final now = DateTime.now();
    return [
      ClippoNotification(
        id: '1',
        title: 'Novo destaque salvo',
        message: 'Seu lance de 3 pontos no Rachão de Quinta foi salvo com sucesso!',
        timestamp: now.subtract(const Duration(minutes: 10)),
        initials: 'CL',
      ),
      ClippoNotification(
        id: '2',
        title: 'Reação ao seu lance',
        message: 'Edu reagiu com 🔥 ao seu highlight.',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 25)),
        initials: 'ED',
      ),
      ClippoNotification(
        id: '3',
        title: 'Novo comentário',
        message: 'Bia comentou: "Jogou muito hoje!! 👏"',
        timestamp: now.subtract(const Duration(hours: 3)),
        initials: 'BI',
      ),
      ClippoNotification(
        id: '4',
        title: 'Solicitação de amizade',
        message: 'Lucas enviou uma solicitação para conectar com você.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        initials: 'LU',
      ),
      ClippoNotification(
        id: '5',
        title: 'Sessão compartilhada',
        message: 'Você foi adicionado aos participantes da sessão "Vôlei de Domingo".',
        timestamp: now.subtract(const Duration(days: 3)),
        initials: 'VD',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final items = List<ClippoNotification>.of(notifications ?? defaultNotifications)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // cronológica decrescente

    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClippoBackButton(onPressed: () => Navigator.of(context).maybePop()),
              const Spacer(),
            ],
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          const ClippoScreenTitle(line1: 'Suas', line2: 'notificações.'),
          const SizedBox(height: ClippoSpace.section),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nenhuma notificação por enquanto.',
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
              ),
            )
          else
            for (final notif in items) ...[
              _NotificationItem(item: notif),
              const SizedBox(height: ClippoSpace.spaceM),
            ],
        ],
      ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.item});

  final ClippoNotification item;

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return Container(
      padding: const EdgeInsets.all(ClippoSpace.spaceM),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClippoAvatar(
            name: item.title,
            photoUrl: item.avatarUrl,
            size: 40,
          ),
          const SizedBox(width: ClippoSpace.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: ClippoText.label.copyWith(color: colors.text),
                      ),
                    ),
                    const SizedBox(width: ClippoSpace.spaceS),
                    Text(
                      _formatRelativeTime(item.timestamp),
                      style: ClippoText.label.copyWith(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: ClippoSpace.labelToValue),
                Text(
                  item.message,
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
