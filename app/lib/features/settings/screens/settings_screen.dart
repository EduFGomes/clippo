import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_message.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/features/profile/screens/profile_screen.dart';
import 'package:clippo/features/profile/widgets/profile_settings_tile.dart';

/// Tela de Configurações do Clippo.
/// Ordem definida pelo produto:
/// 1. Perfil
/// 2. Notificações
/// 3. Resolução da câmera
/// 4. Quantidade de segundos gravados
/// 5. Outros ajustes (Armazenamento, Sobre, etc.)
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.onOpenProfile,
    this.onOpenNotifications,
  });

  final VoidCallback? onOpenProfile;
  final VoidCallback? onOpenNotifications;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _cameraResolution = '1080p (Full HD)';
  int _bufferSeconds = 30;
  bool _recordAudio = true;
  bool _soundOnSave = true;
  bool _flashOnSave = true;
  bool _vibrateOnSave = true;

  static const List<String> _resolutions = [
    '720p (HD)',
    '1080p (Full HD)',
    '4K (Ultra HD)',
  ];

  static const List<int> _secondsOptions = [15, 30, 45, 60];

  void _showConfigExplanation() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final colors = ClippoColors.of(context);
        return AlertDialog(
          backgroundColor: colors.surface,
          title: Row(
            children: [
              Icon(Icons.info_outline, color: colors.accent, size: 24),
              const SizedBox(width: ClippoSpace.spaceS),
              Text('Ajustes Gerais', style: ClippoText.titleS.copyWith(color: colors.text)),
            ],
          ),
          content: Text(
            'As opções definidas aqui nos Ajustes Gerais são os valores PADRÃO para todas as suas futuras gravações.\n\n'
            'Já os ajustes que você altera dentro da tela de Gravar modificam apenas aquela sessão específica, sem sobrescrever suas preferências gerais.',
            style: ClippoText.body.copyWith(color: colors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Entendi', style: ClippoText.label.copyWith(color: colors.accent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickResolution() async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        final colors = ClippoColors.of(context);
        return SimpleDialog(
          backgroundColor: colors.surface,
          title: Text('Resolução da câmera', style: ClippoText.titleS.copyWith(color: colors.text)),
          children: [
            for (final res in _resolutions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(res),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: ClippoSpace.spaceS),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          res,
                          style: ClippoText.body.copyWith(
                            color: res == _cameraResolution ? colors.accent : colors.text,
                            fontWeight: res == _cameraResolution ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (res == _cameraResolution)
                        Icon(Icons.check, color: colors.accent, size: ClippoSize.fieldIcon),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() => _cameraResolution = chosen);
      showClippoMessage(context, 'Resolução alterada para $chosen');
    }
  }

  Future<void> _pickBufferSeconds() async {
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) {
        final colors = ClippoColors.of(context);
        return SimpleDialog(
          backgroundColor: colors.surface,
          title: Text('Segundos gravados no buffer', style: ClippoText.titleS.copyWith(color: colors.text)),
          children: [
            for (final sec in _secondsOptions)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(sec),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: ClippoSpace.spaceS),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$sec segundos',
                          style: ClippoText.body.copyWith(
                            color: sec == _bufferSeconds ? colors.accent : colors.text,
                            fontWeight: sec == _bufferSeconds ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (sec == _bufferSeconds)
                        Icon(Icons.check, color: colors.accent, size: ClippoSize.fieldIcon),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (chosen != null && mounted) {
      setState(() => _bufferSeconds = chosen);
      showClippoMessage(context, 'Buffer ajustado para $chosen segundos');
    }
  }

  Stream<UserProfile?> _resolveProfile() {
    if (isUserSignedIn) return authRepository.watchMyProfile();
    return Stream<UserProfile?>.value(ProfileScreen.demoProfile);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return ClippoScreenGround(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Navigator.of(context).canPop()) ...[
            const ClippoBackButton(),
            const SizedBox(height: ClippoSpace.section),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: ClippoScreenTitle(
                  line1: 'Suas',
                  line2: 'configurações.',
                ),
              ),
              IconButton(
                icon: Icon(Icons.info_outline, color: colors.accent, size: 28),
                tooltip: 'Entenda os ajustes gerais vs gravação',
                onPressed: _showConfigExplanation,
              ),
            ],
          ),
          const SizedBox(height: ClippoSpace.section),

          // 1. Perfil como card de pré-visualização clicável
          StreamBuilder<UserProfile?>(
            stream: _resolveProfile(),
            builder: (context, snapshot) {
              final me = snapshot.data ?? ProfileScreen.demoProfile;
              return InkWell(
                borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                onTap: widget.onOpenProfile ?? () {},
                child: Container(
                  padding: const EdgeInsets.all(ClippoSpace.spaceL),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                    border: Border.all(color: colors.line, width: ClippoSize.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: ClippoSize.avatarLarge,
                        height: ClippoSize.avatarLarge,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.controlSoft,
                          border: Border.all(color: colors.accent, width: ClippoSize.border),
                        ),
                        child: Text(
                          me.name.isNotEmpty ? me.name.substring(0, 1).toUpperCase() : '?',
                          style: ClippoText.titleS.copyWith(color: colors.accent),
                        ),
                      ),
                      const SizedBox(width: ClippoSpace.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.name, style: ClippoText.titleS.copyWith(color: colors.text)),
                            const SizedBox(height: ClippoSpace.labelToValue),
                            Text('@${me.username}', style: ClippoText.body.copyWith(color: colors.textMuted)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 16, color: colors.textLabel),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          // 2. Notificações
          ProfileToggleTile(
            label: 'Notificações',
            value: _notificationsEnabled,
            onChanged: (val) {
              setState(() => _notificationsEnabled = val);
              if (widget.onOpenNotifications != null) widget.onOpenNotifications!();
            },
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          // 3. Resolução da câmera
          ProfileActionTile(
            label: 'Resolução da câmera',
            value: _cameraResolution,
            onTap: _pickResolution,
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          // 4. Quantidade de segundos gravados
          ProfileActionTile(
            label: 'Segundos gravados',
            value: '$_bufferSeconds segundos',
            onTap: _pickBufferSeconds,
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          // 5. Opções de gravação (iguais à tela de gravação)
          ProfileToggleTile(
            label: 'Gravar áudio do ambiente',
            value: _recordAudio,
            onChanged: (val) => setState(() => _recordAudio = val),
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          ProfileToggleTile(
            label: 'Som ao salvar (bip)',
            value: _soundOnSave,
            onChanged: (val) => setState(() => _soundOnSave = val),
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          ProfileToggleTile(
            label: 'Flash ao salvar',
            value: _flashOnSave,
            onChanged: (val) => setState(() => _flashOnSave = val),
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          ProfileToggleTile(
            label: 'Vibração ao salvar',
            value: _vibrateOnSave,
            onChanged: (val) => setState(() => _vibrateOnSave = val),
          ),
          const SizedBox(height: ClippoSpace.spaceM),

          ProfileActionTile(
            label: 'Sobre o Clippo',
            value: 'Versão 1.0.0 (beta)',
            onTap: () => showClippoMessage(context, 'Clippo - Seus melhores lances.'),
          ),
        ],
      ),
    );
  }
}
