import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/data/favorites_repository.dart';
import 'package:clippo/core/data/highlight.dart';
import 'package:clippo/core/data/user_profile.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/upload/upload_queue.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_confirm_dialog.dart';
import 'package:clippo/core/widgets/clippo_highlight_tile.dart';
import 'package:clippo/core/widgets/clippo_message.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/profile/widgets/profile_header.dart';
import 'package:clippo/features/profile/widgets/profile_settings_tile.dart';
import 'package:clippo/features/profile/widgets/profile_stats_bar.dart';

/// Salva nome e/ou @usuário (null = não mudar). Lança [AuthFailure] com a mensagem da tela.
typedef ProfileSaver = Future<void> Function({String? name, String? username});

/// Perfil (docs/produto.md › 4.7): avatar grande, nome e @usuário, três estatísticas
/// (sessões · highlights · amigos), linhas de ajuste (Nome, Usuário), sair da conta e excluir a
/// conta, e trocar ou tirar a foto (12/11/2026). Notificações ficam para o futuro e não aparecem.
///
/// Os dados vêm de `users/{uid}` em tempo real ([AuthRepository.watchMyProfile]); editar chama
/// a Function updateProfile ([AuthRepository.updateProfile]) e a tela se atualiza sozinha.
/// Sem login (catálogo de telas), mostra um perfil de exemplo editado só na memória.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.profile,
    this.saveProfile,
    this.onSignOut,
    this.deleteAccount,
    this.pickPhoto,
    this.savePhoto,
    this.removePhoto,
    this.onOpenFriends,
  });

  /// Abre a galeria ou a câmera e devolve a foto já reduzida (testes trocam). Nulo = image_picker.
  final Future<File?> Function(ImageSource source)? pickPhoto;

  /// Envia a foto (testes trocam). Nulo = [AuthRepository.setProfilePhoto].
  final Future<void> Function(File file)? savePhoto;

  /// Tira a foto (testes trocam). Nulo = [AuthRepository.removeProfilePhoto].
  final Future<void> Function()? removePhoto;

  /// Substitui o perfil em tempo real (testes). Null = Firebase, ou o exemplo sem login.
  final Stream<UserProfile?>? profile;

  /// Substitui o salvar (testes). Null = Function updateProfile, ou só memória sem login.
  final ProfileSaver? saveProfile;

  /// Permite substituir a ação de sair nos testes sem inicializar o Firebase.
  final VoidCallback? onSignOut;

  /// Substitui o excluir conta (testes). Null = tira a fila deste aparelho e chama
  /// [AuthRepository.deleteMyAccount]. Lança [AuthFailure] com a frase da tela.
  final Future<void> Function()? deleteAccount;

  /// Ação ao tocar no contador de amigos.
  final VoidCallback? onOpenFriends;

  /// O perfil mostrado sem login (catálogo de telas).
  static const UserProfile demoProfile = UserProfile(
    uid: 'demo',
    name: 'Gustavo Rocha',
    username: 'gustavo.rocha',
    sessionCount: 12,
    highlightCount: 34,
    friendCount: 8,
  );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _deleting = false;
  bool _photoBusy = false;

  /// Foto quadrada pequena: o avatar aparece no máximo a 88 dp, e 512 px dão nitidez sobrando
  /// num celular de tela densa, com poucos KB para subir.
  static Future<File?> _pickWithSystem(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    return picked == null ? null : File(picked.path);
  }

  /// "Adicionar foto" / "Trocar foto": galeria, câmera e, com foto, tirar a foto.
  Future<void> _editPhoto(UserProfile me) async {
    final hasPhoto = (me.photoUrl ?? '').isNotEmpty;
    final colors = ClippoColors.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(ClippoRadius.radiusField)),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(ClippoSpace.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Foto do perfil', style: ClippoText.titleS.copyWith(color: colors.text)),
              const SizedBox(height: ClippoSpace.spaceL),
              ClippoPrimaryButton(
                label: 'Escolher da galeria',
                onPressed: () => Navigator.of(sheet).pop('gallery'),
              ),
              const SizedBox(height: ClippoSpace.spaceS),
              ClippoTextButton(label: 'Tirar foto', onPressed: () => Navigator.of(sheet).pop('camera')),
              if (hasPhoto)
                ClippoTextButton(label: 'Remover foto', onPressed: () => Navigator.of(sheet).pop('remove')),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'remove') {
      final confirmed = await showClippoConfirm(
        context,
        title: 'Remover a foto?',
        message: 'No lugar dela aparecem as suas iniciais, para você e para os seus amigos.',
        confirmLabel: 'Remover foto',
        cancelLabel: 'Manter foto',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
      await _runPhoto(() => (widget.removePhoto ?? authRepository.removeProfilePhoto)(), 'Foto removida.');
      return;
    }
    final File? file;
    try {
      file = await (widget.pickPhoto ?? _pickWithSystem)(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    } catch (_) {
      if (mounted) {
        showClippoMessage(
          context,
          choice == 'camera'
              ? 'Não deu para abrir a câmera. Confira a permissão nas configurações do celular.'
              : 'Não deu para abrir a galeria.',
        );
      }
      return;
    }
    if (file == null || !mounted) return; // desistiu de escolher
    final picked = file;
    // Regra 0: a mesma conferência do servidor, antes de enviar.
    final error = validateProfilePhoto(await picked.length(), profilePhotoContentType(picked.path));
    if (error != null) {
      if (mounted) showClippoMessage(context, error);
      return;
    }
    if (_useFirebase) {
      await _runPhoto(
        () => (widget.savePhoto ?? (f) => authRepository.setProfilePhoto(f).then((_) {}))(picked),
        'Foto atualizada.',
      );
    } else {
      // Modo local/offline/demo
      setState(() {
        _demoProfile = UserProfile(
          uid: _demoProfile.uid,
          name: _demoProfile.name,
          username: _demoProfile.username,
          photoUrl: picked.path,
          sessionCount: _demoProfile.sessionCount,
          highlightCount: _demoProfile.highlightCount,
          friendCount: _demoProfile.friendCount,
        );
        _demo?.add(_demoProfile);
      });
      if (mounted) showClippoMessage(context, 'Foto atualizada.');
    }
  }

  Future<void> _runPhoto(Future<void> Function() action, String done) async {
    setState(() => _photoBusy = true);
    try {
      await action();
      if (mounted) showClippoMessage(context, done);
    } on AuthFailure catch (e) {
      if (mounted) showClippoMessage(context, e.message);
    } catch (_) {
      if (mounted) showClippoMessage(context, 'Não foi possível trocar a foto. Tente de novo.');
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// Só no modo de exemplo (sem login): o perfil vive aqui.
  StreamController<UserProfile?>? _demo;
  UserProfile _demoProfile = ProfileScreen.demoProfile;

  bool _notificationsEnabled = true;

  late Stream<UserProfile?> _profile = _resolveProfile();

  bool get _useFirebase => widget.profile == null && isUserSignedIn;

  Stream<UserProfile?> _resolveProfile() {
    if (widget.profile != null) return widget.profile!;
    if (_useFirebase) return authRepository.watchMyProfile();
    _demo?.close();
    final demo = _demo = StreamController<UserProfile?>();
    demo.add(_demoProfile);
    return demo.stream;
  }

  @override
  void dispose() {
    _demo?.close();
    super.dispose();
  }

  void _retry() => setState(() => _profile = _resolveProfile());

  /// Sair pede confirmação: um toque sem querer no fim da tela tirava a pessoa da conta.
  Future<void> _signOut() async {
    final confirmed = await showClippoConfirm(
      context,
      title: 'Sair da conta?',
      message: 'Lances que ainda não subiram ficam guardados neste celular e sobem quando você '
          'entrar de novo.',
      confirmLabel: 'Sair',
      cancelLabel: 'Ficar',
    );
    if (!confirmed || !mounted) return;
    (widget.onSignOut ?? () => authRepository.signOut())();
  }

  /// Excluir a conta (LGPD): pergunta antes, com o que acontece com as sessões.
  Future<void> _deleteAccount() async {
    final confirmed = await showClippoConfirm(
      context,
      title: 'Excluir sua conta?',
      message: 'Seu perfil, suas amizades e as sessões que você gravou somem para todo mundo, com '
          'os lances. Das sessões dos outros, você sai. Não dá para desfazer.',
      confirmLabel: 'Excluir conta',
      cancelLabel: 'Manter conta',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    try {
      await (widget.deleteAccount ?? _deleteWithFirebase)();
      // Com a conta excluída, o AuthGate volta às Boas-vindas sozinho.
    } on AuthFailure catch (e) {
      if (mounted) _showError(e.message);
    } catch (_) {
      if (mounted) _showError('Não foi possível excluir a conta. Tente de novo.');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  static Future<void> _deleteWithFirebase() async {
    final uid = authRepository.currentUser?.uid;
    // Os vídeos que ainda não subiram não podem subir depois para uma conta que não existe.
    if (uid != null) await uploadQueue.discardAllOf(uid);
    await authRepository.deleteMyAccount();
  }

  void _showError(String message) => showClippoMessage(context, message);

  Future<void> _save({String? name, String? username}) async {
    final saver = widget.saveProfile;
    if (saver != null) return saver(name: name, username: username);
    if (_useFirebase) return authRepository.updateProfile(name: name, username: username);

    // Exemplo sem login: mesma validação, grava só na memória.
    final nameError = name == null ? null : validateName(name);
    if (nameError != null) throw AuthFailure(nameError, field: 'name');
    final usernameError = username == null ? null : validateUsername(username);
    if (usernameError != null) throw AuthFailure(usernameError, field: 'username');
    final p = _demoProfile;
    _demoProfile = UserProfile(
      uid: p.uid,
      name: name == null ? p.name : normalizeName(name),
      username: username == null ? p.username : normalizeUsername(username),
      photoUrl: p.photoUrl,
      sessionCount: p.sessionCount,
      highlightCount: p.highlightCount,
      friendCount: p.friendCount,
    );
    _demo?.add(_demoProfile);
  }

  Future<void> _editName(UserProfile me) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _EditProfileFieldScreen(
          titleLine1: 'Seu',
          titleLine2: 'nome.',
          subtitle: 'Como você aparece nas sessões com seus amigos.',
          fieldLabel: 'Nome',
          initialValue: me.name,
          textCapitalization: TextCapitalization.words,
          validator: validateName,
          onSave: (value) => _save(name: value),
        ),
      ),
    );
  }

  Future<void> _editUsername(UserProfile me) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _EditProfileFieldScreen(
          titleLine1: 'Seu',
          titleLine2: 'usuário.',
          subtitle: 'Escolha como seus amigos vão te achar.',
          fieldLabel: 'Nome de usuário',
          fieldHint: 'letras, números, "_" e "."',
          prefixText: '@',
          autocorrect: false,
          initialValue: me.username,
          validator: validateUsername,
          onSave: (value) => _save(username: value),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoTextButton(label: 'Sair da conta', onPressed: _deleting ? null : _signOut),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(
            label: _deleting ? 'Excluindo…' : 'Excluir conta',
            onPressed: _deleting ? null : _deleteAccount,
          ),
        ],
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
          StreamBuilder<UserProfile?>(
            stream: _profile,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _Problem(
                  message: 'Não deu para carregar seu perfil. Confira a internet e tente de novo.',
                  onRetry: _retry,
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) return const _Loading();
              final me = snapshot.data;
              if (me == null) {
                return _Problem(message: 'Não achamos seu perfil.', onRetry: _retry);
              }
              return _Content(
                me: me,
                onEditName: () => _editName(me),
                onEditUsername: () => _editUsername(me),
                onEditPhoto: () => _editPhoto(me),
                photoBusy: _photoBusy,
                onTapFriends: widget.onOpenFriends,
                notificationsEnabled: _notificationsEnabled,
                onNotificationsChanged: (enabled) {
                  setState(() => _notificationsEnabled = enabled);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.me,
    required this.onEditName,
    required this.onEditUsername,
    this.onEditPhoto,
    this.photoBusy = false,
    this.onTapFriends,
    this.notificationsEnabled = true,
    this.onNotificationsChanged,
  });

  final UserProfile me;
  final VoidCallback onEditName;
  final VoidCallback onEditUsername;
  final VoidCallback? onEditPhoto;
  final bool photoBusy;
  final VoidCallback? onTapFriends;
  final bool notificationsEnabled;
  final ValueChanged<bool>? onNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeader(
          name: me.name,
          username: me.username,
          photoUrl: me.photoUrl,
          onEditPhoto: onEditPhoto,
          photoBusy: photoBusy,
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        ProfileStatsBar(
          sessions: me.sessionCount,
          highlights: me.highlightCount,
          friends: me.friendCount,
        ),
        const SizedBox(height: ClippoSpace.section),
        ProfileActionTile(
          label: 'Nome',
          value: me.name,
          onTap: onEditName,
        ),
        const SizedBox(height: ClippoSpace.spaceM),
        ProfileActionTile(
          label: 'Usuário',
          value: '@${me.username}',
          onTap: onEditUsername,
        ),
        if (onNotificationsChanged != null) ...[
          const SizedBox(height: ClippoSpace.spaceM),
          ProfileToggleTile(
            label: 'Notificações',
            value: notificationsEnabled,
            onChanged: onNotificationsChanged!,
          ),
        ],
        const SizedBox(height: ClippoSpace.section),
        StreamBuilder<List<Highlight>>(
          stream: favoritesRepository.watchFavorites(),
          builder: (context, snapshot) {
            final favorites = snapshot.data ?? favoritesRepository.favorites;
            final colors = ClippoColors.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lances Favoritos (${favorites.length})',
                  style: ClippoText.titleS.copyWith(color: colors.text),
                ),
                const SizedBox(height: ClippoSpace.spaceS),
                Text(
                  'Visível para você e seus amigos.',
                  style: ClippoText.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: ClippoSpace.spaceM),
                if (favorites.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(ClippoSpace.spaceL),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(ClippoRadius.radiusField),
                    ),
                    child: Center(
                      child: Text(
                        'Nenhum lance favoritado ainda.',
                        style: ClippoText.body.copyWith(color: colors.textMuted),
                      ),
                    ),
                  )
                else
                  for (final highlight in favorites) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: ClippoSpace.spaceM),
                      child: ClippoHighlightTile(
                        title: highlight.title,
                        timing: '${highlight.duration.inSeconds}s',
                        onTap: () {},
                      ),
                    ),
                  ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Esqueleto enquanto o perfil chega.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Semantics(
      label: 'Carregando seu perfil',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(height: ClippoSpace.spaceM),
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

/// Não deu para carregar: mensagem e "Tentar de novo".
class _Problem extends StatelessWidget {
  const _Problem({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: ClippoText.titleS.copyWith(color: colors.text)),
        const SizedBox(height: ClippoSpace.spaceL),
        ClippoPrimaryButton(label: 'Tentar de novo', onPressed: onRetry),
      ],
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
    required this.onSave,
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

  /// Envia o valor (o repositório valida de novo). Lança [AuthFailure] com o erro do servidor.
  final Future<void> Function(String) onSave;

  @override
  State<_EditProfileFieldScreen> createState() => _EditProfileFieldScreenState();
}

class _EditProfileFieldScreenState extends State<_EditProfileFieldScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue);
  String? _errorText;
  bool _saving = false;

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

  Future<void> _submit() async {
    if (_saving) return;
    final error = widget.validator(_controller.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_controller.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    } on AuthFailure catch (e) {
      // Só há um campo nesta tela: o erro do servidor (ex.: @ em uso) aparece embaixo dele.
      if (mounted) setState(() => _errorText = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorText = 'Não foi possível salvar. Tente de novo.');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      footer: ClippoPrimaryButton(
        label: 'Salvar',
        loading: _saving,
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
