// Clippo — tokens de design (direção C).
//
// Fonte única dos valores visuais do app. As tabelas de docs/design.md explicam
// cada token; os nomes aqui são os mesmos de lá. Para mudar ou criar um valor:
// altere aqui E a tabela do design.md no mesmo PR.
//
// Fontes: famílias "Anton" e "Archivo", embutidas em assets/fonts/ e
// registradas no pubspec.yaml.

import 'package:flutter/material.dart';

/// Cores de marca: iguais nos dois temas.
class ClippoBrand {
  ClippoBrand._();

  /// Fundo da boas-vindas; botão primário e destaque no modo claro.
  static const Color wine = Color(0xFF741A2F);

  /// Pressionado de tudo que é vinho.
  static const Color wineDeep = Color(0xFF5C1425);

  /// Accent: \O/ e 2ª linha da boas-vindas; botão primário e destaque no modo escuro.
  static const Color peach = Color(0xFFFFC6A8);

  /// Pressionado de tudo que é pêssego (pêssego a 85 %).
  static const Color peachPressed = Color(0xD9FFC6A8);

  /// Texto sobre vinho.
  static const Color onWine = Color(0xFFFFF1E8);

  /// Texto sobre pêssego.
  static const Color onPeach = Color(0xFF241014);

  // Gravação: ignora o tema. Ainda do design anterior, até a gravação ser redesenhada na C.

  /// Preto puro (OLED): o pixel desliga. Nunca cinza escuro.
  static const Color captureBackground = Color(0xFF000000);
  static const Color captureOverlay = Color(0x99141013); // #141013 a 60 %
  static const Color captureChip = Color(0x1FFFF1E8); // onWine a 12 %
  static const Color captureChipBorder = Color(0x38FFF1E8); // onWine a 22 %
  static const Color captureTextMuted = Color(0xB3FFF1E8); // onWine a 70 %
  static const Color captureRecordRing = Color(0x59FFF1E8); // onWine a 35 %
  static const Color captureGhostBorder = Color(0x52FFF1E8); // onWine a 32 %
}

/// Cores que mudam com o tema. Use via `Theme.of(context).extension<ClippoColors>()!`.
@immutable
class ClippoColors extends ThemeExtension<ClippoColors> {
  const ClippoColors({
    required this.background,
    required this.backgroundGlow,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.textLabel,
    required this.placeholder,
    required this.accent,
    required this.primary,
    required this.primaryPressed,
    required this.onPrimary,
    required this.controlSoft,
    required this.line,
    required this.outline,
    required this.error,
  });

  /// Fundo de tela (abaixo do brilho).
  final Color background;

  /// Topo do degradê de fundo.
  final Color backgroundGlow;

  /// Campos de texto.
  final Color surface;

  /// Texto principal e ícones.
  final Color text;

  /// Subtítulos e descrições.
  final Color textMuted;

  /// Rótulo dentro do campo, ícone do olho.
  final Color textLabel;

  /// Texto de exemplo no campo.
  final Color placeholder;

  /// 2ª linha do título, links, borda de foco, medidor, passo em destaque, ✓.
  final Color accent;

  /// Fundo do botão primário.
  final Color primary;

  /// Botão primário pressionado.
  final Color primaryPressed;

  /// Texto sobre [primary] / [accent] preenchido.
  final Color onPrimary;

  /// Fundo do círculo de voltar.
  final Color controlSoft;

  /// Linha entre passos, traço vazio do medidor.
  final Color line;

  /// Contorno do círculo de passo.
  final Color outline;

  /// Erros de formulário (sempre com texto).
  final Color error;

  static const ClippoColors dark = ClippoColors(
    background: Color(0xFF160A0D),
    backgroundGlow: Color(0xFF4A1220),
    surface: Color(0xFF1E1719),
    text: Color(0xFFFFF1E8),
    textMuted: Color(0x9EFFF1E8), // 62 %
    textLabel: Color(0x8CFFF1E8), // 55 %
    placeholder: Color(0x52FFF1E8), // 32 %
    accent: ClippoBrand.peach,
    primary: ClippoBrand.peach,
    primaryPressed: ClippoBrand.peachPressed,
    onPrimary: ClippoBrand.onPeach,
    controlSoft: Color(0x1AFFF1E8), // 10 %
    line: Color(0x24FFF1E8), // 14 %
    outline: Color(0x4DFFF1E8), // 30 %
    error: Color(0xFFF2B8B5),
  );

  static const ClippoColors light = ClippoColors(
    background: Color(0xFFFBF4F0),
    backgroundGlow: Color(0xFFEED8D5),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF241014),
    textMuted: Color(0xA3241014), // 64 %
    textLabel: Color(0x94241014), // 58 %
    placeholder: Color(0x5C241014), // 36 %
    accent: ClippoBrand.wine,
    primary: ClippoBrand.wine,
    primaryPressed: ClippoBrand.wineDeep,
    onPrimary: ClippoBrand.onWine,
    controlSoft: Color(0x12241014), // 7 %
    line: Color(0x1F241014), // 12 %
    outline: Color(0x40241014), // 25 %
    error: Color(0xFFB3261E),
  );

  /// Atalho para `Theme.of(context).extension<ClippoColors>()!`.
  static ClippoColors of(BuildContext context) => Theme.of(context).extension<ClippoColors>()!;

  @override
  ClippoColors copyWith({
    Color? background,
    Color? backgroundGlow,
    Color? surface,
    Color? text,
    Color? textMuted,
    Color? textLabel,
    Color? placeholder,
    Color? accent,
    Color? primary,
    Color? primaryPressed,
    Color? onPrimary,
    Color? controlSoft,
    Color? line,
    Color? outline,
    Color? error,
  }) {
    return ClippoColors(
      background: background ?? this.background,
      backgroundGlow: backgroundGlow ?? this.backgroundGlow,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textLabel: textLabel ?? this.textLabel,
      placeholder: placeholder ?? this.placeholder,
      accent: accent ?? this.accent,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      onPrimary: onPrimary ?? this.onPrimary,
      controlSoft: controlSoft ?? this.controlSoft,
      line: line ?? this.line,
      outline: outline ?? this.outline,
      error: error ?? this.error,
    );
  }

  @override
  ClippoColors lerp(ThemeExtension<ClippoColors>? other, double t) {
    if (other is! ClippoColors) return this;
    return ClippoColors(
      background: Color.lerp(background, other.background, t)!,
      backgroundGlow: Color.lerp(backgroundGlow, other.backgroundGlow, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textLabel: Color.lerp(textLabel, other.textLabel, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      controlSoft: Color.lerp(controlSoft, other.controlSoft, t)!,
      line: Color.lerp(line, other.line, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Estilos de texto (sem cor: aplique a cor do contexto com copyWith).
/// letterSpacing no Flutter é em pixels: tamanho × fração do token.
class ClippoText {
  ClippoText._();

  static const String display = 'Anton';
  static const String sans = 'Archivo';

  static TextStyle _d(double size, double height, double ls) => TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: height,
        letterSpacing: size * ls,
      );
  static TextStyle _s(double size, FontWeight w, double height) =>
      TextStyle(fontFamily: sans, fontSize: size, fontWeight: w, height: height, letterSpacing: 0);

  // Anton: só título de tela e marca.
  static final TextStyle heroMark = _d(184, 0.82, 0.01); // \O/ da boas-vindas
  static final TextStyle displayL = _d(48, 1.0, 0.01); // título de tela (MAIÚSCULAS, 2 linhas)
  static final TextStyle displayM = _d(40, 1.02, 0.01); // frase da boas-vindas
  static final TextStyle wordmark = _d(20, 1.0, 0.14); // "CLIPPO" no topo da boas-vindas

  // Archivo: todo o resto.
  static final TextStyle titleS = _s(19, FontWeight.w700, 1.2); // título de passo/item
  static final TextStyle input = _s(18, FontWeight.w500, 1.25); // valor digitado
  static final TextStyle button = _s(17, FontWeight.w700, 1.2); // botão primário
  static final TextStyle bodyL = _s(16, FontWeight.w400, 1.4); // subtítulo do título
  static final TextStyle link = _s(16, FontWeight.w600, 1.2); // botão de texto e link
  static final TextStyle linkStrong = _s(16, FontWeight.w700, 1.2); // ação da ClippoLinkLine
  static final TextStyle linkS = _s(15, FontWeight.w600, 1.2); // link ao lado de um erro ("Esqueci a senha")
  static final TextStyle stepNumber = _s(15, FontWeight.w600, 1.0); // número no círculo de passo
  static final TextStyle body = _s(15, FontWeight.w400, 1.45); // descrições
  static final TextStyle errorInline = _s(14, FontWeight.w600, 1.3); // erro na linha do "Esqueci a senha"
  static final TextStyle label = _s(13, FontWeight.w600, 1.3); // rótulo do campo, legenda, erro

  /// Contadores, tempos e placares: algarismos de largura fixa.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

class ClippoSpace {
  ClippoSpace._();

  static const double spaceXs = 4; // entre traços do medidor
  static const double spaceS = 6; // primário → botão de texto; título → descrição do passo; recuo do medidor
  static const double spaceM = 10; // entre campos; campo → medidor; campos → linha de erro
  static const double spaceL = 18; // círculo do passo → texto; respiro lateral do campo
  static const double gutter = 28; // margem lateral das telas
  static const double section = 32; // voltar → título; subtítulo → 1º campo
  static const double sectionL = 48; // topo → voltar; título → lista de passos
  static const double screenBottom = 34; // último botão → base (+ área segura)

  static const double titleToSubtitle = 12; // título → subtítulo
  static const double labelToValue = 3; // rótulo do campo → valor
  static const double fieldPaddingV = 12; // respiro vertical do campo
  static const double fieldPaddingEndWithAction = 8; // respiro à direita do campo com botão
  static const double stepGap = 36; // entre passos da ClippoStepList

  // Boas-vindas.
  static const double welcomeTop = 60; // topo → "CLIPPO"
  static const double welcomeHeroToPhrase = 26; // \O/ → frase
  static const double welcomePhraseToActions = 56; // frase → botões
}

class ClippoRadius {
  ClippoRadius._();
  static const double radiusField = 18; // campos
  static const double radiusPill = 999; // botões, círculos, traços do medidor
}

class ClippoSize {
  ClippoSize._();
  static const double buttonHeight = 58; // botão primário
  static const double textButtonHeight = 48; // botão de texto
  static const double control = 44; // desenho do círculo de voltar e do botão do olho
  static const double minTouchTarget = 48; // área de toque mínima de qualquer controle
  static const double step = 36; // círculo de passo
  static const double check = 26; // círculo do ✓
  static const double meter = 4; // espessura do traço do medidor
  static const double glowHeight = 460; // altura do degradê do topo

  static const double backIcon = 22; // chevron do voltar
  static const double fieldIcon = 20; // olho dentro do campo
  static const double checkIcon = 16; // ✓ dentro do círculo check
  static const double spinner = 20; // indicador de carregando dentro do botão
  static const double iconStroke = 1.8; // traço dos ícones de controle
  static const double checkStroke = 3; // traço do ✓
  static const double border = 1.5; // borda de foco/erro, contorno e linha dos passos
}

/// Opacidades de estado.
class ClippoOpacity {
  ClippoOpacity._();
  static const double disabled = 0.45; // controle desabilitado
  static const double textButton = 0.85; // botão de texto
}

class ClippoMotion {
  ClippoMotion._();

  /// Curva padrão: sai rápido e assenta devagar.
  static const Curve standard = Cubic(0.2, 0.8, 0.2, 1);

  /// Camada vinho some ao entrar vindo da boas-vindas.
  static const Duration enterFromWelcome = Duration(milliseconds: 700);

  /// Borda de foco do campo, traço do medidor.
  static const Duration focus = Duration(milliseconds: 160);

  /// Botão desabilitado → habilitado.
  static const Duration enable = Duration(milliseconds: 200);

  // Gravação (comportamento descrito em docs/produto.md › 4.5).
  static const Duration standbyPulse = Duration(milliseconds: 2600); // ciclo do ponto pulsante
  static const Duration savedBanner = Duration(milliseconds: 2600); // aviso "Highlight salvo"
  static const Duration stopControls = Duration(milliseconds: 3200); // controles após um toque

  /// Sem animação quando o sistema pede "reduzir movimento".
  static bool reduced(BuildContext context) => MediaQuery.of(context).disableAnimations;
}

/// ThemeData do app: `MaterialApp(theme: clippoTheme(Brightness.light), darkTheme: clippoTheme(Brightness.dark))`.
ThemeData clippoTheme(Brightness b) {
  final c = b == Brightness.dark ? ClippoColors.dark : ClippoColors.light;
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ClippoBrand.wine,
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      secondary: ClippoBrand.peach,
      onSecondary: ClippoBrand.onPeach,
      surface: c.background,
      onSurface: c.text,
      error: c.error,
    ),
    fontFamily: ClippoText.sans,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionHandleColor: c.accent),
    splashFactory: NoSplash.splashFactory, // plano: sem ripple; pressionado muda a cor
    extensions: [c],
  );
}
