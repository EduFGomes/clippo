import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/onboarding/screens/sign_in_screen.dart';
import 'package:clippo/features/onboarding/widgets/onboarding_scaffold.dart';

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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'As senhas não são iguais.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authRepository.signUp(email: _email.text, password: _password.text);
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ClippoColors>()!;
    return OnboardingScaffold(
      title: 'Criar conta',
      primaryLabel: 'Criar conta',
      loading: _loading,
      onPrimary: _submit,
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SignInScreen()),
        ),
        child: const Text('Já tenho conta'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: ClippoSpace.cardGap),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: 'Senha', helperText: 'Pelo menos 6 caracteres'),
          ),
          const SizedBox(height: ClippoSpace.cardGap),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Confirme a senha'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: ClippoSpace.cardGap),
            Text(_error!, style: ClippoText.caption.copyWith(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
