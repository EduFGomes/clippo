import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    this.userName,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? avatarUrl;
  final String? userName;
  final bool read;

  factory ClippoNotification.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return ClippoNotification(
      id: doc.id,
      title: data['title'] as String? ?? 'Notificação',
      message: data['message'] as String? ?? '',
      timestamp: timestamp,
      avatarUrl: data['avatarUrl'] as String?,
      userName: data['userName'] as String? ?? data['senderName'] as String?,
      read: data['read'] as bool? ?? false,
    );
  }
}

/// Tela de notificações em ordem cronológica (mais recente pro mais antigo).
/// Conectada em tempo real à subcoleção Firestore `users/{uid}/notifications`.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    this.notifications,
  });

  final List<ClippoNotification>? notifications;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final user = FirebaseAuth.instance.currentUser;

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
          Expanded(
            child: user == null
                ? _buildEmptyState(colors)
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('notifications')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erro ao carregar notificações.',
                            style: ClippoText.body.copyWith(color: colors.textMuted),
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return _buildEmptyState(colors);
                      }

                      final items = docs
                          .map((doc) => ClippoNotification.fromFirestore(doc))
                          .toList();

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: ClippoSpace.spaceM),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return _NotificationCard(notification: item);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ClippoColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 56, color: colors.textMuted),
            const SizedBox(height: ClippoSpace.spaceM),
            Text(
              'Nenhuma notificação por enquanto.',
              textAlign: TextAlign.center,
              style: ClippoText.titleS.copyWith(color: colors.text),
            ),
            const SizedBox(height: ClippoSpace.spaceS),
            Text(
              'Novas reações, comentários e convites para sessões aparecerão aqui em ordem cronológica.',
              textAlign: TextAlign.center,
              style: ClippoText.body.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final ClippoNotification notification;

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);

    return Container(
      padding: const EdgeInsets.all(ClippoSpace.spaceM),
      decoration: BoxDecoration(
        color: notification.read ? colors.surface : colors.controlSoft,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
        border: Border.all(
          color: notification.read ? colors.line : colors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClippoAvatar(
            name: notification.userName ?? notification.title,
            photoUrl: notification.avatarUrl,
            size: 40,
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
                        notification.title,
                        style: ClippoText.titleS.copyWith(
                          color: colors.text,
                          fontWeight: notification.read ? FontWeight.w500 : FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimeAgo(notification.timestamp),
                      style: ClippoText.label.copyWith(color: colors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                Text(
                  notification.message,
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
