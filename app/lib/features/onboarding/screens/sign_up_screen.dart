import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
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
  String? _error;
  String? _errorField;

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

  /// O e-mail é validado pelo Firebase ao enviar; aqui só a senha e a confirmação.
  bool get _valid =>
      _password.text.length >= ClippoPasswordMeter.minLength && _confirm.text == _password.text;

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      setState(() {
        _error = 'As senhas não são iguais.';
        _errorField = 'password';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _errorField = null;
    });
    try {
      await authRepository.signUp(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      setState(() {
        _error = e.message;
        _errorField = e.field;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _fieldHasError(String field) =>
      _error != null && (_errorField == field || _errorField == AuthFailure.credentialsField);

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
            hasError: _fieldHasError('email'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField.password(
            label: 'Senha',
            hint: 'mínimo de 6 caracteres',
            controller: _password,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            hasError: _fieldHasError('password'),
          ),
          ClippoPasswordMeter(length: _password.text.length),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField.confirmation(
            label: 'Confirme a senha',
            hint: 'repita a senha',
            controller: _confirm,
            password: _password,
            textInputAction: TextInputAction.done,
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
