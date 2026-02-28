import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2E5BFF);
}

// ── YANGI: Stats sahifasi uchun dinamik mavzu extension ──
class StatsTheme extends ThemeExtension<StatsTheme> {
  final Color income;
  final Color expense;
  final Color active;
  final Color pending;
  final Color textSecondary;
  final Color border;
  final Color cardColor;

  StatsTheme({
    required this.income,
    required this.expense,
    required this.active,
    required this.pending,
    required this.textSecondary,
    required this.border,
    required this.cardColor,
  });

  @override
  ThemeExtension<StatsTheme> copyWith({
    Color? income, Color? expense, Color? active, Color? pending,
    Color? textSecondary, Color? border, Color? cardColor,
  }) {
    return StatsTheme(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      active: active ?? this.active,
      pending: pending ?? this.pending,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      cardColor: cardColor ?? this.cardColor,
    );
  }

  @override
  ThemeExtension<StatsTheme> lerp(ThemeExtension<StatsTheme>? other, double t) {
    if (other is! StatsTheme) return this;
    return StatsTheme(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      active: Color.lerp(active, other.active, t)!,
      pending: Color.lerp(pending, other.pending, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      cardColor: Color.lerp(cardColor, other.cardColor, t)!,
    );
  }
}


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
    extensions: [
      StatsTheme(
        income: const Color(0xFF00C853),
        expense: const Color(0xFFEF5350),
        active: const Color(0xFF3498DB),
        pending: const Color(0xFFFF9100),
        textSecondary: const Color(0xFF7B8BB2),
        border: const Color(0xFFDDE1EF),
        cardColor: Colors.white,
      ),
    ],
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
    extensions: [
      StatsTheme(
        income: const Color(0xFF81C784), // Bir oz ochroq yashil
        expense: const Color(0xFFE57373), // Bir oz ochroq qizil
        active: const Color(0xFF64B5F6), 
        pending: const Color(0xFFFFB74D),
        textSecondary: const Color(0xFFB0B8D1),
        border: Colors.white12,
        cardColor: const Color(0xFF1E1E1E),
      ),
    ],
  );

  // 3. OYNASIMON (GLASS) MAVZU
  static final ThemeData glassTheme = ThemeData(
    brightness: Brightness.dark, // Yozuvlar oq bo'lishi uchun asosi Dark
    scaffoldBackgroundColor: Colors.transparent, // Asosiy oyna to'liq shaffof
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // AppBar to'liq shaffof
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    cardTheme: CardTheme(
      color: Colors.white.withOpacity(0.05), // Ichi qo'shimcha ravishda judayam ozroq oqariq 
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24), // Kattaroq egovli chekkalar (rasmdagidek iOS silliq)
        side: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5), // Juda nozik 0.5 px chegara chizig'i
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Colors.white),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
    extensions: [
      StatsTheme(
        income: Colors.greenAccent,
        expense: Colors.redAccent,
        active: Colors.lightBlueAccent,
        pending: Colors.orangeAccent,
        textSecondary: Colors.white70,
        border: Colors.white24,
        cardColor: Colors.white.withOpacity(0.05),
      ),
    ],
  );
}
