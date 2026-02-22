import 'package:flutter/material.dart';

class AppThemes {
  // 1. STANDART (OQ) MAVZU
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FE),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Color(0xFF2E5BFF)),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
  );

  // 2. QORONG'U (DARK) MAVZU
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      elevation: 1,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1E1E1E),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.blueAccent),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );

  // 3. OYNASIMON (GLASS) MAVZU
  static final ThemeData glassTheme = ThemeData(
    brightness: Brightness.dark, // Yozuvlar oq bo'lishi uchun asosi Dark
    scaffoldBackgroundColor: Colors.transparent, // ENG MUHIMI: Orqa fon yo'q!
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // AppBar ham shaffof
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardTheme(
      color: Colors.white.withOpacity(0.15), // KARTALAR YARIM SHAFFOF OYNA BO'LADI
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1), // Oyna chekkasi
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}
