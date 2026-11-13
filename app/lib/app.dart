import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:clippo/core/data/auth_repository.dart';
import 'package:clippo/core/theme/clippo_tokens.dart';
import 'package:clippo/core/widgets/clippo_primary_button.dart';
import 'package:clippo/core/widgets/clippo_screen_ground.dart';
import 'package:clippo/core/widgets/clippo_screen_title.dart';
import 'package:clippo/core/widgets/clippo_text_button.dart';
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
      // Calendário, relógio e botões do sistema em PT-BR, com hora de 24 h (regra 1 do AGENTS.md).
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
          return const StartupLoading();
        }
        final user = snapshot.data;
        if (user == null) return const WelcomeScreen();
        return ProfileGate(key: ValueKey(user.uid), uid: user.uid);
      },
    );
  }
}

/// Logado: o perfil existe? Público para os testes (com [hasProfile] e [signOut] de mentira).
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.uid, this.hasProfile, this.signOut, this.app});

  final String uid;

  /// Nulo = `authRepository.hasProfile`.
  final Future<bool> Function(String uid)? hasProfile;

  /// Nulo = `authRepository.signOut`.
  final Future<void> Function()? signOut;

  /// A tela do app depois do perfil. Nulo = `AppShell` (os testes trocam).
  final Widget? app;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<bool> _hasProfile = _check();

  Future<bool> _check() => (widget.hasProfile ?? authRepository.hasProfile)(widget.uid);

  // Corpo com chaves: com "=>" o callback devolveria a Future e o setState a recusa.
  void _recheck() => setState(() {
        _hasProfile = _check();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _hasProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const StartupLoading();
        if (snapshot.hasError) {
          final offline = snapshot.error is ProfileOfflineException;
          return StartupProblem(
            line1: offline ? 'Sem' : 'Não deu',
            line2: offline ? 'internet.' : 'para abrir.',
            message: offline
                ? 'Na primeira vez neste celular, o Clippo precisa de internet para carregar sua conta. '
                    'Depois, dá para gravar mesmo sem sinal.'
                : 'Não foi possível carregar seu perfil. Tente de novo em instantes.',
            onRetry: _recheck,
            onSignOut: () => (widget.signOut ?? authRepository.signOut)(),
          );
        }
        if (snapshot.data == true) return widget.app ?? const AppShell();
        return CompleteProfileScreen(onCompleted: _recheck);
      },
    );
  }
}

/// Enquanto o app descobre quem está logado: vinho com o CLIPPO no centro, continuando a
/// abertura do Android (mesma cor) até a Boas-vindas ou a Início. Antes era um círculo girando
/// sobre branco, fora do design.
class StartupLoading extends StatelessWidget {
  const StartupLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClippoBrand.wine,
      body: Semantics(
        label: 'Abrindo o Clippo',
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text('CLIPPO', style: ClippoText.wordmark.copyWith(color: ClippoBrand.onWine)),
              ),
              const SizedBox(height: ClippoSpace.spaceL),
              const SizedBox.square(
                dimension: ClippoSize.spinner,
                child: CircularProgressIndicator(strokeWidth: ClippoSize.border, color: ClippoBrand.onWine),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A abertura não conseguiu seguir (sem internet na primeira vez, erro do servidor): explica,
/// tenta de novo e deixa sair da conta, para ninguém ficar preso nesta tela.
class StartupProblem extends StatelessWidget {
  const StartupProblem({
    super.key,
    required this.line1,
    required this.line2,
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String line1;
  final String line2;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ClippoScreenGround(
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClippoPrimaryButton(label: 'Tentar de novo', onPressed: onRetry),
          const SizedBox(height: ClippoSpace.spaceS),
          ClippoTextButton(label: 'Sair da conta', onPressed: onSignOut),
        ],
      ),
      child: Semantics(
        liveRegion: true,
        child: ClippoScreenTitle(line1: line1, line2: line2, subtitle: message),
      ),
    );
  }
}
