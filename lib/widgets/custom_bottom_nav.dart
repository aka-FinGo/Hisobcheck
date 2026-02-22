import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            color: Colors.black.withOpacity(.1),
          )
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
          child: GNav(
            rippleColor: Colors.grey[300]!,
            hoverColor: Colors.grey[100]!,
            gap: 8,
            activeColor: const Color(0xFF2E5BFF),
            iconSize: 26,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            duration: const Duration(milliseconds: 400),
            tabBackgroundColor: const Color(0xFF2E5BFF).withOpacity(0.1),
            color: Colors.grey[600]!,
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
  }
}
