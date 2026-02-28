import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class CustomBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChange;

  const CustomBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isGlass = themeProvider.currentMode == AppThemeMode.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget navContent = Container(
      decoration: BoxDecoration(
        color: isGlass ? Colors.white.withOpacity(0.05) : Theme.of(context).cardTheme.color,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
          )
        ],
        border: isGlass 
            ? Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 0.5))
            : null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
          child: GNav(
            rippleColor: isDark ? Colors.white10 : Colors.grey[300]!,
            hoverColor: isDark ? Colors.white12 : Colors.grey[100]!,
            gap: 8,
            activeColor: isGlass ? Colors.tealAccent : const Color(0xFF2E5BFF),
            iconSize: 26,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: isGlass 
                ? Colors.white.withOpacity(0.1) 
                : const Color(0xFF2E5BFF).withOpacity(0.1),
            color: isDark ? Colors.white60 : Colors.grey[600]!,
            tabs: const [
              GButton(icon: Icons.home_rounded, text: 'Asosiy'),
              GButton(icon: Icons.people_alt_rounded, text: 'Mijozlar'),
              GButton(icon: Icons.list_alt_rounded, text: 'Zakazlar'),
              GButton(icon: Icons.bar_chart_rounded, text: 'Hisobot'),
              GButton(icon: Icons.person_rounded, text: 'Profil'),
            ],
            selectedIndex: selectedIndex,
            onTabChange: onTabChange,
          ),
        ),
      ),
    );

    if (isGlass) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: navContent,
        ),
      );
    }

    return navContent;
  }
}
