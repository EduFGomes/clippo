import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_link_line.dart';
import 'package:clippo/core/widgets/clippo_password_meter.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';

/// Entrada · Criar conta com e-mail e senha.
/// Depois que a conta nasce no Firebase Auth, o AuthGate leva para "Complete seu perfil".
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  /// Erro de cada campo (validação do app ou resposta do Firebase).
  final Map<String, String> _fieldErrors = {};

  /// Erro que não é de um campo (ex.: sem internet).
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(_refresh);
    _confirm.addListener(_refresh);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Habilita o botão; o e-mail é conferido ao tocar (o erro aparece embaixo do campo).
  bool get _valid =>
      validateNewPassword(_password.text) == null &&
      validatePasswordConfirmation(_password.text, _confirm.text) == null;

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
      'email': validateEmail(_email.text),
      'password': validateNewPassword(_password.text),
      'confirm': validatePasswordConfirmation(_password.text, _confirm.text),
    }..removeWhere((_, error) => error == null);
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors.cast<String, String>());
      _error = null;
    });
    if (errors.isNotEmpty) return; // nada vai para o Firebase sem passar na validação

    setState(() => _loading = true);
    try {
      await authRepository.signUp(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
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
    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(
            label: 'Criar conta',
            enabled: _valid,
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoLinkLine(
            prefix: 'Já tem conta?',
            action: 'Entrar',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
            ),
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
            line1: 'Criar',
            line2: 'conta.',
            subtitle: 'Seus lances ficam guardados na sua conta.',
          ),
          const SizedBox(height: ClippoSpace.section),
          ClippoTextField(
            label: 'E-mail',
            hint: 'voce@email.com',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            errorText: _fieldErrors['email'],
            onChanged: (_) => _clearError('email'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField.password(
            label: 'Senha',
            hint: 'mínimo de 6 caracteres',
            controller: _password,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            errorText: _fieldErrors['password'],
            onChanged: (_) => _clearError('password'),
          ),
          ClippoPasswordMeter(length: _password.text.length),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField.confirmation(
            label: 'Confirme a senha',
            hint: 'repita a senha',
            controller: _confirm,
            password: _password,
            textInputAction: TextInputAction.done,
            errorText: _fieldErrors['confirm'],
            onChanged: (_) => _clearError('confirm'),
            onSubmitted: (_) {
              if (_valid && !_loading) _submit();
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: ClippoSpace.spaceM),
            Text(_error!, style: ClippoText.label.copyWith(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
