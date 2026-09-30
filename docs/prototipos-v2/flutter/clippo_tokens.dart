// Clippo — tokens de design para Flutter.
//
// Espelha docs/design-tokens.json (v2.0.0). Itens marcados com "v2" são
// propostas do protótipo v2 (docs/prototipos-v2) e só devem ir para o
// design-tokens.json se o grupo aprovar.
//
// Fontes: declare no pubspec.yaml as famílias "BricolageGrotesque"
// (700, 800) e "InstrumentSans" (400, 600), ou troque os TextStyle abaixo
// por GoogleFonts.bricolageGrotesque(...) / GoogleFonts.instrumentSans(...).

import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';

/// Cores de marca: iguais nos dois temas.
class ClippoBrand {
  ClippoBrand._();

  static const Color wine = Color(0xFF741A2F);
  static const Color wineDeep = Color(0xFF5C1425);
  static const Color onWine = Color(0xFFFFF1E8);
  static const Color peach = Color(0xFFFFC6A8);
  static const Color onPeach = Color(0xFF241014);

  /// Gravação: ignora o tema. Preto puro (OLED).
  static const Color captureBackground = Color(0xFF000000);
  static const Color captureOverlay = Color(0x99141013); // #141013 a 60 %
  static const Color captureChip = Color(0x1FFFF1E8); // onWine a 12 %
  static const Color captureChipBorder = Color(0x38FFF1E8); // onWine a 22 %
  static const Color captureTextMuted = Color(0xB3FFF1E8); // onWine a 70 %
  static const Color captureRecordRing = Color(0x59FFF1E8); // onWine a 35 %
  static const Color captureGhostBorder = Color(0x52FFF1E8); // onWine a 32 %

  static const List<Color> thumbnailPlaceholder = [
    Color(0xFF3A2A2F),
    Color(0xFF2E2327),
    Color(0xFF43302F),
    Color(0xFF2A2226),
  ];
  static const Color thumbnailPlayScrim = Color(0x8C141013); // a 55 %
}

/// Cores que mudam com o tema. Use via Theme.of(context).extension<ClippoColors>()!
@immutable
class ClippoColors extends ThemeExtension<ClippoColors> {
  const ClippoColors({
    required this.background,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.divider,
    required this.accentForeground,
    required this.accentSoft,
    required this.cardOpenBorder,
    required this.skeleton,
    required this.error,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color divider;
  final Color accentForeground;
  final Color accentSoft;
  final Color cardOpenBorder;
  final Color skeleton;
  final Color error;

  static const ClippoColors light = ClippoColors(
    background: Color(0xFFFBF4F0),
    surface: Color(0xFFF3E4DC),
    text: Color(0xFF241014),
    // v2: 64 % em vez de 60 % — passa 4,5:1 também sobre surface.
    textMuted: Color(0xA3241014),
    divider: Color(0x1A241014), // 10 %
    accentForeground: ClippoBrand.wine,
    accentSoft: Color(0x21741A2F), // 13 %
    cardOpenBorder: Color(0x47741A2F), // 28 %
    skeleton: Color(0xFFEAD5C9),
    error: Color(0xFFB3261E),
  );

  static const ClippoColors dark = ClippoColors(
    background: Color(0xFF141013),
    surface: Color(0xFF1E1719),
    text: Color(0xFFF6ECE7),
    textMuted: Color(0x9EF6ECE7), // 62 %
    divider: Color(0x21F6ECE7), // 13 %
    accentForeground: ClippoBrand.peach,
    accentSoft: Color(0x6B741A2F), // 42 %
    cardOpenBorder: Color(0x47741A2F),
    skeleton: Color(0xFF2A2023),
    error: Color(0xFFF2B8B5),
  );

  @override
  ClippoColors copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? textMuted,
    Color? divider,
    Color? accentForeground,
    Color? accentSoft,
    Color? cardOpenBorder,
    Color? skeleton,
    Color? error,
  }) {
    return ClippoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      accentForeground: accentForeground ?? this.accentForeground,
      accentSoft: accentSoft ?? this.accentSoft,
      cardOpenBorder: cardOpenBorder ?? this.cardOpenBorder,
      skeleton: skeleton ?? this.skeleton,
      error: error ?? this.error,
    );
  }

  @override
  ClippoColors lerp(ThemeExtension<ClippoColors>? other, double t) {
    if (other is! ClippoColors) return this;
    return ClippoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      cardOpenBorder: Color.lerp(cardOpenBorder, other.cardOpenBorder, t)!,
      skeleton: Color.lerp(skeleton, other.skeleton, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

/// Estilos de texto (sem cor: aplique a cor do contexto com copyWith).
/// letterSpacing no Flutter é em pixels: tamanho × fração do token.
class ClippoText {
  ClippoText._();

  static const String display = 'BricolageGrotesque';
  static const String body = 'InstrumentSans';

  static TextStyle _d(double size, FontWeight w, double height, double ls) =>
      TextStyle(fontFamily: display, fontSize: size, fontWeight: w, height: height, letterSpacing: size * ls);
  static TextStyle _b(double size, FontWeight w, double height, [double ls = 0]) =>
      TextStyle(fontFamily: body, fontSize: size, fontWeight: w, height: height, letterSpacing: size * ls);

  static final TextStyle impactNumber = _d(64, FontWeight.w800, 0.9, -0.03); // v2
  static final TextStyle screenTitle = _d(38, FontWeight.w800, 1.02, -0.03);
  static final TextStyle sessionTitle = _d(36, FontWeight.w800, 1.02, -0.03);
  static final TextStyle statNumber = _d(34, FontWeight.w800, 1.0, 0);
  static final TextStyle formTitle = _d(32, FontWeight.w800, 1.04, -0.03);
  static final TextStyle profileName = _d(30, FontWeight.w800, 1.1, -0.02);
  static final TextStyle cardTitleOpen = _d(25, FontWeight.w800, 1.1, -0.02);
  static final TextStyle sectionTitle = _d(22, FontWeight.w800, 1.1, -0.02);
  static final TextStyle cardTitle = _d(20, FontWeight.w700, 1.1, -0.02);
  static final TextStyle toastTitle = _d(20, FontWeight.w800, 1.2, -0.01);
  static final TextStyle fieldValue = _d(20, FontWeight.w700, 1.2, 0);
  static final TextStyle itemTitle = _d(18, FontWeight.w700, 1.15, -0.01);

  static final TextStyle button = _b(15, FontWeight.w600, 1.2);
  static final TextStyle buttonSmall = _b(13.5, FontWeight.w600, 1.2);
  static final TextStyle bodyText = _b(14, FontWeight.w400, 1.4);
  static final TextStyle bodyStrong = _b(14, FontWeight.w600, 1.4);
  static final TextStyle caption = _b(13, FontWeight.w400, 1.4);
  static final TextStyle meta = _b(12.5, FontWeight.w600, 1.3);
  static final TextStyle overline = _b(11.5, FontWeight.w600, 1.3, 0.04); // use .toUpperCase() no texto
  static final TextStyle navLabel = _b(10.5, FontWeight.w600, 1.2);

  /// Contadores, tempos e placares: algarismos de largura fixa.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];
}

class ClippoSpace {
  ClippoSpace._();
  static const double screenGutter = 20;
  static const double screenTop = 14;
  static const double cardGap = 12;
  static const double rowGap = 11;
  static const double sectionGap = 22;
  static const double listBottomInsetWithNav = 130;
  static const double minTouchTarget = 48;
  static const EdgeInsets impactHeaderPadding = EdgeInsets.fromLTRB(22, 16, 22, 26);
}

class ClippoRadius {
  ClippoRadius._();
  static const double none = 0; // blocos de impacto e miniaturas
  static const double medium = 22; // linha de highlight, cards de campo
  static const double large = 30; // card de sessão em destaque
  static const double full = 999; // pílulas e círculos
}

class ClippoSize {
  ClippoSize._();
  static const double navBarHeight = 66;
  static const double navBarInsetX = 24;
  static const double navBarInsetBottom = 22;
  static const double navItemWidth = 82;
  static const double recordButton = 88;
  static const double captureTopButton = 42;
  static const double standbyDot = 11;
  static const double iconStroke = 1.6;
  static const double thumbnailRowWidth = 108; // linha compacta
  static const double thumbnailRowHeight = 68;
  static const double thumbnailStripWidth = 136; // v2: tira de lances 16:9
  static const double thumbnailStripHeight = 77;
  static const double feedAspectRatio = 16 / 9; // v2: feed da Sessão e capa da Início
}

class ClippoMotion {
  ClippoMotion._();
  static const Curve standard = Cubic(0.2, 0.8, 0.2, 1);
  static const Curve pop = Cubic(0.34, 1.56, 0.64, 1); // v2: "\ o /" entrando
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration base = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 380);
  static const Duration standbyPulse = Duration(milliseconds: 2600); // escala 1→1,9, opacidade .45→1
  static const Duration savedBanner = Duration(milliseconds: 2600); // entra 0–12 %, sai a partir de 82 %
  static const Duration stopControls = Duration(milliseconds: 3200);
}

/// ThemeData base. Exemplo:
///   MaterialApp(theme: clippoTheme(Brightness.light), darkTheme: clippoTheme(Brightness.dark))
ThemeData clippoTheme(Brightness b) {
  final c = b == Brightness.dark ? ClippoColors.dark : ClippoColors.light;
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    scaffoldBackgroundColor: c.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ClippoBrand.wine,
      brightness: b,
      primary: ClippoBrand.wine,
      onPrimary: ClippoBrand.onWine,
      secondary: ClippoBrand.peach,
      onSecondary: ClippoBrand.onPeach,
      surface: c.surface,
      onSurface: c.text,
      error: c.error,
    ),
    fontFamily: ClippoText.body,
    splashFactory: NoSplash.splashFactory, // plano: sem ripple; pressionado = wineDeep
    extensions: [c],
  );
}
