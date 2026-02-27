import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// RANG KONSTANTALARI
// ══════════════════════════════════════════════════════════════

class AppColors {
  // ── LIGHT ─────────────────────────────────────────────────
  static const lightBg        = Color(0xFFF4F6FB);
  static const lightCard      = Colors.white;
  static const lightPrimary   = Color(0xFF2E5BFF);
  static const lightText      = Color(0xFF1A1F36);
  static const lightSubText   = Color(0xFF6B7A9F);
  static const lightBorder    = Color(0xFFE4E9F2);

  // ── DARK (NEON) ────────────────────────────────────────────
  // Rasmday: to'q navy-purple fon, neon cyan+purple accent
  static const darkBg         = Color(0xFF0A0E1A); // Eng to'q navy
  static const darkBg2        = Color(0xFF0F1428); // Karta foni
  static const darkCard       = Color(0xFF141B2D); // Karta
  static const darkCardBorder = Color(0xFF1E2D4A); // Karta chekka
  static const neonCyan       = Color(0xFF00D4FF); // Asosiy neon
  static const neonPurple     = Color(0xFF7B2FFF); // Ikkinchi neon
  static const neonPink       = Color(0xFFFF2D7A); // Uchunchi accent
  static const darkText       = Color(0xFFE8EEFF);
  static const darkSubText    = Color(0xFF6B7FA3);

  // ── GLASS ─────────────────────────────────────────────────
  // bg.jpg ustiga qo'yiladi — fon rasmga qarab
  static const glassCard      = Color(0x22FFFFFF); // 13% oq
  static const glassBorder    = Color(0x44FFFFFF); // 27% oq
  static const glassText      = Colors.white;
  static const glassSubText   = Color(0xCCFFFFFF); // 80% oq
}

// ══════════════════════════════════════════════════════════════
// TEMA CLASSI
// ══════════════════════════════════════════════════════════════

class AppThemes {

  // ────────────────────────────────────────────────────────────
  // 1. LIGHT TEMA — Toza, professional
  // ────────────────────────────────────────────────────────────
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.lightBg,
    primaryColor: AppColors.lightPrimary,
    colorScheme: const ColorScheme.light(
      primary: AppColors.lightPrimary,
      secondary: Color(0xFF00C6AE),
      surface: AppColors.lightCard,
      error: Color(0xFFE53935),
    ),

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x1A2E5BFF),
      iconTheme: IconThemeData(color: AppColors.lightText),
      titleTextStyle: TextStyle(
        color: AppColors.lightText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),

    // Kartalar
    cardTheme: CardTheme(
      color: AppColors.lightCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.lightBorder, width: 1),
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF8FAFF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.lightPrimary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.lightSubText),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.lightPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // BottomNav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.lightPrimary,
      unselectedItemColor: AppColors.lightSubText,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // ListTile
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.lightPrimary,
      titleTextStyle: TextStyle(color: AppColors.lightText, fontSize: 15, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(color: AppColors.lightSubText, fontSize: 13),
    ),

    // Matnlar
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w800),
      headlineMedium:TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge:    TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge:     TextStyle(color: AppColors.lightText, fontSize: 16),
      bodyMedium:    TextStyle(color: AppColors.lightSubText, fontSize: 14),
      bodySmall:     TextStyle(color: AppColors.lightSubText, fontSize: 12),
    ),

    iconTheme: const IconThemeData(color: AppColors.lightSubText),
    dividerColor: AppColors.lightBorder,
  );


  // ────────────────────────────────────────────────────────────
  // 2. DARK / NEON TEMA — Rasmday: navy + cyan + purple
  // ────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBg,
    primaryColor: AppColors.neonCyan,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.neonCyan,
      secondary: AppColors.neonPurple,
      surface: AppColors.darkCard,
      error: AppColors.neonPink,
      onPrimary: AppColors.darkBg,
      onSurface: AppColors.darkText,
    ),

    // AppBar — shaffof, gradient chiziqsiz
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBg.withOpacity(0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: AppColors.neonCyan),
      titleTextStyle: const TextStyle(
        color: AppColors.darkText,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),

    // Kartalar — rasmday: to'q, neon border
    cardTheme: CardTheme(
      color: AppColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.darkCardBorder, width: 1),
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkBg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.darkCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        // Fokusda neon cyan porlaydi
        borderSide: const BorderSide(color: AppColors.neonCyan, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.darkSubText),
      hintStyle: const TextStyle(color: AppColors.darkSubText),
    ),

    // ElevatedButton — neon gradient
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neonCyan,
        foregroundColor: AppColors.darkBg,
        elevation: 0,
        shadowColor: AppColors.neonCyan.withOpacity(0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.neonCyan,
        side: const BorderSide(color: AppColors.neonCyan, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // BottomNav — to'q fon, neon selected
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBg2,
      selectedItemColor: AppColors.neonCyan,
      unselectedItemColor: AppColors.darkSubText,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // TabBar
    tabBarTheme: const TabBarTheme(
      labelColor: AppColors.neonCyan,
      unselectedLabelColor: AppColors.darkSubText,
      indicatorColor: AppColors.neonCyan,
    ),

    // ListTile
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.neonCyan,
      titleTextStyle: TextStyle(color: AppColors.darkText, fontSize: 15, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(color: AppColors.darkSubText, fontSize: 13),
      tileColor: AppColors.darkCard,
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.neonCyan : AppColors.darkSubText),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.neonCyan.withOpacity(0.3)
              : AppColors.darkCardBorder),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkBg2,
      selectedColor: AppColors.neonCyan.withOpacity(0.2),
      labelStyle: const TextStyle(color: AppColors.darkText, fontSize: 13),
      side: const BorderSide(color: AppColors.darkCardBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Matnlar
    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w800),
      headlineMedium:TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge:    TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge:     TextStyle(color: AppColors.darkText, fontSize: 16),
      bodyMedium:    TextStyle(color: AppColors.darkSubText, fontSize: 14),
      bodySmall:     TextStyle(color: AppColors.darkSubText, fontSize: 12),
    ),

    iconTheme: const IconThemeData(color: AppColors.darkSubText),
    dividerColor: AppColors.darkCardBorder,
    dialogBackgroundColor: AppColors.darkCard,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkCard,
      contentTextStyle: const TextStyle(color: AppColors.darkText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.darkCardBorder),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );


  // ────────────────────────────────────────────────────────────
  // 3. GLASS TEMA — bg.jpg ustiga haqiqiy glassmorphism
  //    (rasmday: kulrang-oq shaffof kartalar, aniq border)
  // ────────────────────────────────────────────────────────────
  static final ThemeData glassTheme = ThemeData(
    brightness: Brightness.dark,

    // ⚠️ MUHIM: transparent bo'lishi shart — bg.jpg ko'rinishi uchun
    scaffoldBackgroundColor: Colors.transparent,
    primaryColor: Colors.white,
    colorScheme: ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white.withOpacity(0.7),
      surface: AppColors.glassCard,
      onSurface: AppColors.glassText,
    ),

    // AppBar — to'liq shaffof
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black.withOpacity(0.1),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        shadows: [Shadow(color: Colors.black26, blurRadius: 8)],
      ),
    ),

    // Kartalar — rasmday: oq shaffof, aniq border
    cardTheme: CardTheme(
      color: AppColors.glassCard,       // 13% oq
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Colors.white.withOpacity(0.35), // Rasmday aniq ko'rinadi
          width: 1,
        ),
      ),
      margin: EdgeInsets.zero,
    ),

    // Input — yarim shaffof
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.1),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.8), width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
    ),

    // ElevatedButton — oq, to'q matn
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.white.withOpacity(0.4)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // BottomNav — kulrang shaffof
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: Colors.black.withOpacity(0.25),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white.withOpacity(0.45),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),

    // TabBar
    tabBarTheme: TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white.withOpacity(0.5),
      indicatorColor: Colors.white,
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      iconColor: Colors.white.withOpacity(0.9),
      titleTextStyle: const TextStyle(
        color: AppColors.glassText,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
      ),
      subtitleTextStyle: TextStyle(
        color: Colors.white.withOpacity(0.65),
        fontSize: 13,
      ),
      tileColor: Colors.white.withOpacity(0.08),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? Colors.white : Colors.white54),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? Colors.white.withOpacity(0.4)
              : Colors.white.withOpacity(0.15)),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withOpacity(0.1),
      selectedColor: Colors.white.withOpacity(0.25),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      side: BorderSide(color: Colors.white.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // Matnlar — oq, soya bilan o'qilishi yaxshi bo'ladi
    textTheme: TextTheme(
      displayLarge:  const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      headlineMedium:const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge:    const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
      bodyLarge:     const TextStyle(color: Colors.white, fontSize: 16),
      bodyMedium:    TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
      bodySmall:     TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
    ),

    iconTheme: const IconThemeData(color: Colors.white),
    dividerColor: Colors.white.withOpacity(0.15),
    dialogBackgroundColor: Colors.white.withOpacity(0.15),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.black.withOpacity(0.5),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}