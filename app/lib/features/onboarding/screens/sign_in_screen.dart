import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/features/onboarding/screens/sign_up_screen.dart';
import 'package:clippo/features/onboarding/widgets/onboarding_scaffold.dart';

/// Entrada · Entrar com e-mail e senha.
/// "Entrar com Google" entra quando o projeto real do Firebase existir (precisa de configuração do Google).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await authRepository.signIn(email: _email.text, password: _password.text);
      // A raiz do app (AuthGate) percebe o login e mostra a tela certa; aqui só fechamos a pilha.
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
      title: 'Entrar',
      primaryLabel: 'Entrar',
      loading: _loading,
      onPrimary: _submit,
      secondary: TextButton(
        onPressed: () => Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
        ),
        child: const Text('Ainda não tenho conta'),
      ),
      child: Column(
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
          const SizedBox(height: ClippoSpace.spaceM),
          TextField(
            controller: _password,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(labelText: 'Senha'),
            onSubmitted: (_) => _submit(),
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
