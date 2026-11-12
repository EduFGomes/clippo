import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/format/date_input_formatter.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_confirm_dialog.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// O que o "Como cuidamos dos seus dados" explica, ao lado da data de nascimento.
/// 🟡 Resumo até o grupo ter uma política de privacidade completa para linkar aqui.
const String clippoPrivacySummary =
    'Seu nome, seu @ e sua foto aparecem para quem usa o Clippo, para seus amigos te acharem. '
    'A data de nascimento fica guardada à parte: só você e o servidor do Clippo leem, e ela não '
    'aparece no seu perfil. Seus lances aparecem só para quem participou da sessão. '
    'Para apagar tudo, use Perfil › Excluir conta.';

/// Entrada · Complete seu perfil (não desenhada na C; segue o padrão das outras telas).
/// Vale para quem criou conta por e-mail e, no futuro, pelo Google.
/// Envia os dados para a Cloud Function completeProfile, que valida e grava no Firestore.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.onCompleted, this.usernameTaken});

  /// Confere se o @ já é de outra pessoa ao sair do campo. Nulo = o do `authRepository`
  /// (com alguém logado); sem login (catálogo, testes), não confere.
  final Future<bool> Function(String username)? usernameTaken;

  /// Chamado quando o perfil foi criado (o AuthGate usa para seguir em frente).
  final VoidCallback? onCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  /// Digitada como "dd/mm/aaaa" (a máscara põe as barras). O seletor de calendário saiu em
  /// 10/11/2026: para data de nascimento, caçar o ano no calendário era pior que digitar.
  final _birthDateText = TextEditingController();
  final _usernameFocus = FocusNode();
  bool _loading = false;

  /// O @ conferido por último ao sair do campo (para não ler de novo o mesmo).
  String? _checkedUsername;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_onUsernameFocus);
  }

  /// Saiu do campo do @: confere o formato e se já é de alguém, antes de enviar. Antes, a
  /// pessoa só descobria no "Continuar", depois de preencher tudo.
  Future<void> _onUsernameFocus() async {
    if (_usernameFocus.hasFocus) return;
    final raw = _username.text;
    if (raw.trim().isEmpty) return;
    final error = validateUsername(raw);
    if (error != null) {
      setState(() => _fieldErrors['username'] = error);
      return;
    }
    final username = normalizeUsername(raw);
    if (username == _checkedUsername) return;
    _checkedUsername = username;
    final check = widget.usernameTaken ?? (isUserSignedIn ? authRepository.isUsernameTaken : null);
    if (check == null) return;
    final taken = await check(username);
    if (!mounted || normalizeUsername(_username.text) != username) return;
    if (taken) setState(() => _fieldErrors['username'] = usernameTakenMessage);
  }

  /// Erro de cada campo (validação do app ou resposta da Function).
  final Map<String, String> _fieldErrors = {};

  /// Erro que não é de um campo (ex.: sem internet).
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _usernameFocus.dispose();
    _birthDateText.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field) || _error != null) {
      setState(() {
        _fieldErrors.remove(field);
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final errors = <String, String?>{
      'name': validateName(_name.text),
      'username': validateUsername(_username.text),
      'birthDate': validateBirthDateText(_birthDateText.text),
    }..removeWhere((_, error) => error == null);
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors.cast<String, String>());
      _error = null;
    });
    if (errors.isNotEmpty) return; // nada vai para a Function sem passar na validação

    setState(() => _loading = true);
    try {
      await authRepository.completeProfile(
        name: _name.text,
        username: _username.text,
        birthDate: birthDateIso(parseBirthDateText(_birthDateText.text)!),
      );
      widget.onCompleted?.call();
    } on AuthFailure catch (e) {
      setState(() {
        if (e.field == null) {
          _error = e.message;
        } else {
          _fieldErrors[e.field!] = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final generalError = _error;
    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(label: 'Continuar', loading: _loading, onPressed: _submit),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(label: 'Sair', onPressed: () => authRepository.signOut()),
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
            line1: 'Quase',
            line2: 'lá.',
            subtitle: 'Escolha como seus amigos vão te achar.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: 'Nome',
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            errorText: _fieldErrors['name'],
            onChanged: (_) => _clearError('name'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Nome de usuário',
            hint: 'letras, números, "_" e "."',
            controller: _username,
            focusNode: _usernameFocus,
            prefixText: '@',
            autocorrect: false,
            textInputAction: TextInputAction.next,
            errorText: _fieldErrors['username'],
            onChanged: (_) => _clearError('username'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Data de nascimento',
            hint: 'dd/mm/aaaa',
            controller: _birthDateText,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.birthday],
            inputFormatters: const [DateInputFormatter()],
            errorText: _fieldErrors['birthDate'],
            onChanged: (_) => _clearError('birthDate'),
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL),
            child: Text(
              'Não aparece no seu perfil. Usamos só para estatísticas gerais.',
              style: ClippoText.label.copyWith(color: colors.textMuted),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ClippoTextButton(
              label: 'Como cuidamos dos seus dados',
              onPressed: () => showClippoNotice(
                context,
                title: 'Seus dados no Clippo',
                message: clippoPrivacySummary,
              ),
            ),
          ),
          if (generalError != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Text(generalError, style: ClippoText.label.copyWith(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
