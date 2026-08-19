import 'package:flutter/material.dart';

/// Design tokens shared with Noor Majlis.
///
/// NOTE: `06-design-system.md` and `sharik-prototype-en.html` were not present
/// in the repo when this was built, so these values are inferred from the build
/// brief (New=amber, Running=green, Done=grey, dark-green total panel, gold
/// action panel). Swap this file for the real tokens when the design system
/// lands — nothing else references raw colours.
class NoorColors {
  const NoorColors._();

  static const Color ink = Color(0xFF1A1D1A);
  static const Color inkSoft = Color(0xFF5A615C);
  static const Color inkFaint = Color(0xFF8C948E);

  static const Color paper = Color(0xFFF6F4EE);
  static const Color card = Color(0xFFFFFFFF);
  static const Color hairline = Color(0xFFE3DFD5);

  /// The dark green panel — the biggest number on the order screen sits here.
  static const Color forest = Color(0xFF14432F);
  static const Color forestSoft = Color(0xFF1E5B41);

  /// Tab + status colours. He reads the app by colour before he reads a word.
  static const Color amber = Color(0xFFE08A1E);
  static const Color amberSoft = Color(0xFFFCF1DE);
  static const Color green = Color(0xFF2E7D5B);
  static const Color greenSoft = Color(0xFFE4F1EA);
  static const Color grey = Color(0xFF8A8F98);
  static const Color greySoft = Color(0xFFEFEFF1);

  /// The one actionable stage on the ladder.
  static const Color gold = Color(0xFFC8922A);
  static const Color goldSoft = Color(0xFFFBF3E0);

  static const Color danger = Color(0xFFB3402F);
}

class NoorSpacing {
  const NoorSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class NoorRadius {
  const NoorRadius._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
}

ThemeData buildNoorTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: NoorColors.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: NoorColors.forest,
      secondary: NoorColors.gold,
      surface: NoorColors.card,
      error: NoorColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: NoorColors.paper,
      foregroundColor: NoorColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: NoorColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: NoorColors.ink,
      displayColor: NoorColors.ink,
    ),
    dividerColor: NoorColors.hairline,
  );
}

/// Large, unambiguous type. The seller reads this on a cheap phone in bad light.
class NoorText {
  const NoorText._();

  static const TextStyle hero = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: -1.2,
  );
  static const TextStyle figure = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.05,
    letterSpacing: -0.8,
  );
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle body = TextStyle(fontSize: 15, height: 1.35);
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
  );
}
