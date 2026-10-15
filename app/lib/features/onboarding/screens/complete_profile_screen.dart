import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';

/// Entrada · Complete seu perfil (não desenhada na C; segue o padrão das outras telas).
/// Vale para quem criou conta por e-mail e, no futuro, pelo Google.
/// Envia os dados para a Cloud Function completeProfile, que valida e grava no Firestore.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.onCompleted});

  /// Chamado quando o perfil foi criado (o AuthGate usa para seguir em frente).
  final VoidCallback? onCompleted;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _birthDateText = TextEditingController();
  DateTime? _birthDate;
  bool _loading = false;
  String? _error;
  String? _errorField;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _birthDateText.dispose();
    super.dispose();
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _display(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateText.text = _display(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (_birthDate == null) {
      setState(() {
        _error = 'Informe a data de nascimento.';
        _errorField = 'birthDate';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _errorField = null;
    });
    try {
      await authRepository.completeProfile(
        name: _name.text,
        username: _username.text,
        birthDate: _iso(_birthDate!),
      );
      widget.onCompleted?.call();
    } on AuthFailure catch (e) {
      setState(() {
        _error = e.message;
        _errorField = e.field;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _fieldError(String field) => _errorField == field ? _error : null;

  @override
  Widget build(BuildContext context) {
    final colors = ClippoColors.of(context);
    final generalError = _error != null && _errorField == null ? _error : null;
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
            errorText: _fieldError('name'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Nome de usuário',
            hint: 'letras, números, "_" e "."',
            controller: _username,
            prefixText: '@',
            autocorrect: false,
            textInputAction: TextInputAction.next,
            errorText: _fieldError('username'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField(
            label: 'Data de nascimento',
            hint: 'dd/mm/aaaa',
            controller: _birthDateText,
            readOnly: true,
            onTap: _pickBirthDate,
            errorText: _fieldError('birthDate'),
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ClippoSpace.spaceL),
            child: Text(
              'Não aparece no seu perfil. Usamos só para estatísticas gerais.',
              style: ClippoText.label.copyWith(color: colors.textMuted),
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
