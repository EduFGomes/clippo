import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/app_shell.dart';
import 'package:clippo/features/onboarding/screens/complete_profile_screen.dart';
import 'package:clippo/features/onboarding/screens/welcome_screen.dart';

/// Raiz do app: temas claro/escuro e a tela inicial.
class ClippoApp extends StatelessWidget {
  const ClippoApp({super.key, this.home});

  /// Permite trocar a tela inicial (os testes usam o catálogo, sem Firebase).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clippo',
      debugShowCheckedModeBanner: false,
      theme: clippoTheme(Brightness.light),
      darkTheme: clippoTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: home ?? const AuthGate(),
    );
  }
}

/// Decide a primeira tela a partir de quem está logado:
///   ninguém logado        → Boas-vindas
///   logado, sem perfil    → Complete seu perfil
///   logado, com perfil    → app (AppShell: as seções e a roda de navegação)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authRepository.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();
        return _ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.uid});

  final String uid;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late Future<bool> _hasProfile = authRepository.hasProfile(widget.uid);

  // Corpo com chaves: com "=>" o callback devolveria a Future e o setState a recusa.
  void _recheck() => setState(() {
        _hasProfile = authRepository.hasProfile(widget.uid);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const _Loading();
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: _recheck,
                child: const Text('Não foi possível carregar seu perfil. Tentar de novo'),
              ),
            ),
          );
        }
        if (snapshot.data == true) return const AppShell();
        return CompleteProfileScreen(onCompleted: _recheck);
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
