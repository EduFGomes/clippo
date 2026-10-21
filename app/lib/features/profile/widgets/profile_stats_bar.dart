import 'package:flutter/material.dart';

import 'package:clippo/core/theme/clippo_tokens.dart';

/// Resumo rápido do perfil com três contadores: sessões, highlights e amigos.
class ProfileStatsBar extends StatelessWidget {
  const ProfileStatsBar({
    super.key,
    required this.sessions,
    required this.highlights,
    required this.friends,
  });

  final int sessions;
  final int highlights;
  final int friends;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ClippoSpace.spaceM,
        vertical: ClippoSpace.spaceL,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatColumn(value: sessions, label: 'sessões'),
            ),
            Container(width: ClippoSize.border, color: colors.line),
            Expanded(
              child: _StatColumn(value: highlights, label: 'highlights'),
            ),
            Container(width: ClippoSize.border, color: colors.line),
            Expanded(
              child: _StatColumn(value: friends, label: 'amigos'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceXs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$value',
              textAlign: TextAlign.center,
              style: ClippoText.titleS.copyWith(
                color: colors.text,
                fontFeatures: ClippoText.tabular,
              ),
            ),
            const SizedBox(height: ClippoSpace.labelToValue),
            Text(
              label,
              textAlign: TextAlign.center,
              style: ClippoText.label.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
