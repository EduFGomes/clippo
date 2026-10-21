import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/profile/widgets/profile_header.dart';
import 'package:clippo/features/profile/widgets/profile_settings_tile.dart';
import 'package:clippo/features/profile/widgets/profile_stats_bar.dart';

/// Perfil (docs/produto.md › 4.7): avatar grande, nome e @usuário, três estatísticas
/// (sessões · highlights · amigos), linhas de ajuste (Nome, Usuário, Notificações) e sair da conta.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.initialName = 'Gustavo Rocha',
    this.initialUsername = 'gustavo.rocha',
    this.initialSessions = 12,
    this.initialHighlights = 34,
    this.initialFriends = 8,
    this.initialNotificationsEnabled = true,
    this.onSignOut,
  });

  final String initialName;
  final String initialUsername;
  final int initialSessions;
  final int initialHighlights;
  final int initialFriends;
  final bool initialNotificationsEnabled;

  /// Permite substituir a ação de sair nos testes sem inicializar o Firebase.
  final VoidCallback? onSignOut;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _name = widget.initialName;
  late String _username = widget.initialUsername;
  late bool _notificationsEnabled = widget.initialNotificationsEnabled;

  Future<void> _editName() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _EditProfileFieldScreen(
          titleLine1: 'Seu',
          titleLine2: 'nome.',
          subtitle: 'Como você aparece nas sessões com seus amigos.',
          fieldLabel: 'Nome',
          initialValue: _name,
          textCapitalization: TextCapitalization.words,
          validator: validateName,
          normalizer: normalizeName,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _name = updated);
    }
  }

  Future<void> _editUsername() async {
    final updated = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _EditProfileFieldScreen(
          titleLine1: 'Seu',
          titleLine2: 'usuário.',
          subtitle: 'Escolha como seus amigos vão te achar.',
          fieldLabel: 'Nome de usuário',
          fieldHint: 'letras, números, "_" e "."',
          prefixText: '@',
          autocorrect: false,
          initialValue: _username,
          validator: validateUsername,
          normalizer: normalizeUsername,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _username = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      footer: ClippoTextButton(
        label: 'Sair da conta',
        onPressed: widget.onSignOut ?? () => authRepository.signOut(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (Navigator.of(context).canPop()) ...[
            const ClippoBackButton(),
            const SizedBox(height: ClippoSpace.section),
          ],
          const ClippoScreenTitle(
            line1: 'Seu',
            line2: 'perfil.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ProfileHeader(
            name: _name,
            username: _username,
            onEditPhoto: () {},
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ProfileStatsBar(
            sessions: widget.initialSessions,
            highlights: widget.initialHighlights,
            friends: widget.initialFriends,
          ),
          const SizedBox(height: ClippoSpace.section),
          ProfileActionTile(
            label: 'Nome',
            value: _name,
            onTap: _editName,
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ProfileActionTile(
            label: 'Usuário',
            value: '@$_username',
            onTap: _editUsername,
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ProfileToggleTile(
            label: 'Notificações',
            value: _notificationsEnabled,
            onChanged: (enabled) => setState(() => _notificationsEnabled = enabled),
          ),
        ],
      ),
    );
  }
}

class _EditProfileFieldScreen extends StatefulWidget {
  const _EditProfileFieldScreen({
    required this.titleLine1,
    required this.titleLine2,
    required this.subtitle,
    required this.fieldLabel,
    required this.initialValue,
    required this.validator,
    required this.normalizer,
    this.fieldHint,
    this.prefixText,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final String titleLine1;
  final String titleLine2;
  final String subtitle;
  final String fieldLabel;
  final String? fieldHint;
  final String? prefixText;
  final String initialValue;
  final TextCapitalization textCapitalization;
  final bool autocorrect;
  final String? Function(String) validator;
  final String Function(String) normalizer;

  @override
  State<_EditProfileFieldScreen> createState() => _EditProfileFieldScreenState();
}

class _EditProfileFieldScreenState extends State<_EditProfileFieldScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  void _submit() {
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(widget.normalizer(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      footer: ClippoPrimaryButton(
        label: 'Salvar',
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ClippoBackButton(),
          const SizedBox(height: ClippoSpace.section),
          ClippoScreenTitle(
            line1: widget.titleLine1,
            line2: widget.titleLine2,
            subtitle: widget.subtitle,
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: widget.fieldLabel,
            hint: widget.fieldHint,
            controller: _controller,
            prefixText: widget.prefixText,
            textCapitalization: widget.textCapitalization,
            autocorrect: widget.autocorrect,
            textInputAction: TextInputAction.done,
            errorText: _errorText,
            onChanged: (_) => _clearError(),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
    );
  }
}
