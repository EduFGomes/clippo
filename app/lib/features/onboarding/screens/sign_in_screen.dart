import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/validation/input_validation.dart';
import 'package:clippo/core/widgets/clippo_back_button.dart';
import 'package:clippo/core/widgets/clippo_link_line.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_field.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';

/// Entrada · Entrar com e-mail e senha.
/// "Entrar com Google" entra quando o projeto real do Firebase existir (precisa de configuração do Google).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.enterFromWelcome = false});

  /// Veio do "Já tenho conta" da boas-vindas: entra com o vinho se desfazendo.
  final bool enterFromWelcome;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  /// Erro de cada campo (validação do app ou resposta do Firebase).
  final Map<String, String> _fieldErrors = {};

  /// Erro da linha do "Esqueci a senha" (credenciais erradas, sem internet…).
  String? _error;

  /// "E-mail ou senha incorretos.": os dois campos ficam marcados.
  bool _credentialsError = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clearError(String field) {
    if (_fieldErrors.containsKey(field) || _error != null) {
      setState(() {
        _fieldErrors.remove(field);
        _error = null;
        _credentialsError = false;
      });
    }
  }

  Future<void> _submit() async {
    final errors = <String, String?>{
      'email': validateEmail(_email.text),
      'password': validateExistingPassword(_password.text),
    }..removeWhere((_, error) => error == null);
    setState(() {
      _fieldErrors
        ..clear()
        ..addAll(errors.cast<String, String>());
      _error = null;
      _credentialsError = false;
    });
    if (errors.isNotEmpty) return; // nada vai para o Firebase sem passar na validação

    setState(() => _loading = true);
    try {
      await authRepository.signIn(email: _email.text, password: _password.text);
      // A raiz do app (AuthGate) percebe o login e mostra a tela certa; aqui só fechamos a pilha.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      setState(() {
        if (e.field == null || e.field == AuthFailure.credentialsField) {
          _error = e.message;
          _credentialsError = e.field == AuthFailure.credentialsField;
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
      enterFromWelcome: widget.enterFromWelcome,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(label: 'Entrar', loading: _loading, onPressed: _submit),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoLinkLine(
            prefix: 'Ainda não tem conta?',
            action: 'Criar conta',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
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
            line1: 'De volta',
            line2: 'ao jogo.',
            subtitle: 'Seus highlights estão te esperando.',
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
            hasError: _credentialsError,
            errorText: _fieldErrors['email'],
            onChanged: (_) => _clearError('email'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          ClippoTextField.password(
            label: 'Senha',
            hint: 'sua senha',
            controller: _password,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            hasError: _credentialsError,
            errorText: _fieldErrors['password'],
            onChanged: (_) => _clearError('password'),
            onSubmitted: (_) {
              if (!_loading) _submit();
            },
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _error == null
                    ? const SizedBox.shrink()
                    : Text(_error!, style: ClippoText.errorInline.copyWith(color: colors.error)),
              ),
              const SizedBox(width: ClippoSpace.spaceM),
              // 🟡 A recuperação de senha ainda não existe (docs/arquitetura.md › Decisões em aberto).
              Text('Esqueci a senha', style: ClippoText.linkS.copyWith(color: colors.accent)),
            ],
          ),
        ],
      ),
    );
  }
}
