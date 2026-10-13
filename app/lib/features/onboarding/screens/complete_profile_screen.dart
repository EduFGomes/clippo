import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/onboarding/widgets/onboarding_scaffold.dart';

/// Entrada · Complete seu perfil (tela nova, fora do protótipo).
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
  DateTime? _birthDate;
  bool _loading = false;
  String? _error;
  String? _errorField;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
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
    if (picked != null) setState(() => _birthDate = picked);
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
    final colors = Theme.of(context).extension<ClippoColors>()!;
    final generalError = _error != null && _errorField == null ? _error : null;
    return OnboardingScaffold(
      title: 'Complete seu perfil',
      subtitle: 'É assim que seus amigos vão te encontrar.',
      primaryLabel: 'Salvar',
      loading: _loading,
      onPrimary: _submit,
      secondary: TextButton(
        onPressed: () => authRepository.signOut(),
        child: const Text('Sair'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nome', errorText: _fieldError('name')),
          ),
          const SizedBox(height: ClippoSpace.cardGap),
          TextField(
            controller: _username,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Nome de usuário',
              prefixText: '@',
              helperText: 'Letras, números, "_" e "."',
              errorText: _fieldError('username'),
            ),
          ),
          const SizedBox(height: ClippoSpace.cardGap),
          OutlinedButton(
            onPressed: _pickBirthDate,
            style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
            child: Text(_birthDate == null ? 'Data de nascimento' : _display(_birthDate!)),
          ),
          const SizedBox(height: 4),
          Text(
            _fieldError('birthDate') ?? 'Não aparece no seu perfil. Usamos só para estatísticas gerais.',
            style: ClippoText.caption.copyWith(
              color: _fieldError('birthDate') != null ? colors.error : colors.textMuted,
            ),
          ),
          if (generalError != null) ...[
            const SizedBox(height: ClippoSpace.cardGap),
            Text(generalError, style: ClippoText.caption.copyWith(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
