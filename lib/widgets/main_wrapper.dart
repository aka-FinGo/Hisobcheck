import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';
import 'pwa_prompt.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
    HomeScreen(onNavigateToTab: (index) => setState(() => _currentIndex = index)),
    ClientsScreen(),
    OrdersListScreen(),
    StatsScreen(),
    UserProfileScreen(),
  ];

  // Rasmdagi dizayn: oq bar, tepada egri (dip), tanlangan — oq doira
  static const double _navBarHeight = 72;
  static const double _notchRadius = 28;
  static const double _circleSize = 56;
  static const Color _barWhite = Colors.white;
  static const Color _iconLabelColor = Color(0xFF1A1A1A);
  static const Color _iconInactiveColor = Color(0xFF757575);
  static const Color _scaffoldBg = Color(0xFFF8F9FE);

  final List<Map<String, dynamic>> navItems = [
    {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded, 'label': 'Asosiy'},
    {'icon': Icons.people_outline, 'activeIcon': Icons.people_alt_rounded, 'label': 'Mijozlar'},
    {'icon': Icons.list_alt_outlined, 'activeIcon': Icons.list_alt_rounded, 'label': 'Zakazlar'},
    {'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart_rounded, 'label': 'Hisobot'},
    {'icon': Icons.person_outline, 'activeIcon': Icons.person_rounded, 'label': 'Profil'},
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = screenWidth / navItems.length;
    final notchCenterX = itemWidth * _currentIndex + itemWidth / 2;

    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: SizedBox(
        height: _navBarHeight + MediaQuery.of(context).padding.bottom,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Oq bar — tepada tanlangan tab atrofida egri (dip)
            ClipPath(
              clipper: _NotchBarClipper(
                notchCenterX: notchCenterX,
                notchRadius: _notchRadius,
                barHeight: _navBarHeight,
              ),
              child: Container(
                width: screenWidth,
                height: _navBarHeight,
                color: _barWhite,
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              ),
            ),
            // 2. Tanlangan element — yuqoriga chiqadigan oq doira
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              left: notchCenterX - _circleSize / 2,
              top: -_notchRadius,
              child: Container(
                width: _circleSize,
                height: _circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _barWhite,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
            // 3. Ikonkalar va yozuvlar (tanlangan ikonka doira ichida)
            Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              child: Row(
                children: List.generate(navItems.length, (index) {
                  final isActive = _currentIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: itemWidth,
                      height: _navBarHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Yozuv — pastda, barcha tablar uchun
                          Positioned(
                            bottom: 10,
                            child: Text(
                              navItems[index]['label'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive ? _iconLabelColor : _iconInactiveColor,
                              ),
                            ),
                          ),
                          // Ikonka — tanlangan yuqorida (doira ichida), noaktiv pastroq
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeInOut,
                            top: isActive ? 4 : 14,
                            child: Icon(
                              isActive ? navItems[index]['activeIcon'] : navItems[index]['icon'],
                              size: 26,
                              color: isActive ? _iconLabelColor : _iconInactiveColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oq bar uchun tepada egri (dip) — tanlangan tab ostida kesik
class _NotchBarClipper extends CustomClipper<Path> {
  final double notchCenterX;
  final double notchRadius;
  final double barHeight;

  _NotchBarClipper({
    required this.notchCenterX,
    required this.notchRadius,
    required this.barHeight,
  });

  @override
  Path getClip(Size size) {
    final w = size.width;
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(notchCenterX - notchRadius, 0);
    path.arcTo(
      Rect.fromCircle(center: Offset(notchCenterX, notchRadius), radius: notchRadius),
      math.pi,
      -math.pi,
      false,
    );
    path.lineTo(w, 0);
    path.lineTo(w, barHeight);
    path.lineTo(0, barHeight);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _NotchBarClipper old) =>
      old.notchCenterX != notchCenterX || old.notchRadius != notchRadius;
}
