import 'package:flutter/material.dart';

// --- EKRANLAR IMPORTI (O'zingizdagi yo'llar bilan tekshirib oling) ---
import '../screens/home_screen.dart'; // Faqat Dashboard qismini qoldirganingizga ishonch hosil qiling
import '../screens/clients_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';

// PWA taklifi uchun
import 'pwa_prompt.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;

  // Sahifalar ro'yxati (bosh sahifaga tab o'tish callback beriladi)
  List<Widget> get _pages => [
    HomeScreen(onNavigateToTab: (index) => setState(() => _currentIndex = index)),
    ClientsScreen(),
    OrdersListScreen(),
    StatsScreen(),
    UserProfileScreen(),
  ];

  // Yashil tema: pastki navbar
  final Color bgColor = const Color(0xFFF8F9FE);      // Dastur orqa foni
  final Color navColor = const Color(0xFF00C853);    // Navbar fon — yashil
  final Color activeColor = Colors.white;            // Aktiv tab indikatori (oq doira)
  final Color activeIconColor = const Color(0xFF00C853); // Aktiv ikonka rang (yashil)
  static const Color _inactiveIconColor = Colors.white70; // Noaktiv ikonka
  static const Color _inactiveLabelColor = Colors.white70; // Noaktiv yozuv

  // Ikonkalar va Yozuvlar ro'yxati
  final List<Map<String, dynamic>> navItems = [
    {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded, 'label': 'Asosiy'},
    {'icon': Icons.people_outline, 'activeIcon': Icons.people_alt_rounded, 'label': 'Mijozlar'},
    {'icon': Icons.list_alt_outlined, 'activeIcon': Icons.list_alt_rounded, 'label': 'Zakazlar'},
    {'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart_rounded, 'label': 'Hisobot'},
    {'icon': Icons.settings_outlined, 'activeIcon': Icons.settings_rounded, 'label': 'Profil'},
  ];

  @override
  void initState() {
    super.initState();
    // PWA (Ekranga o'rnatish) oynasini chaqirish
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ekranning kengligini hisoblash (5 ta tab uchun bo'lamiz)
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = screenWidth / navItems.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // Maxsus Suyuq Menyu (Animated Navbar)
      bottomNavigationBar: Container(
        height: 70,
        decoration: BoxDecoration(
          color: navColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. CSS'dagi ".indicator" (Aylanib yuruvchi pufakcha va kesik)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              top: -25, // CSS'dagi translateY(-35px) ga mos keladi
              left: (_currentIndex * itemWidth) + (itemWidth - 60) / 2, // 60 pufakcha kengligi
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // --- CSS "Water Blow" effektlari ---
                  // Chap yon tomondagi bukilgan qism (pseudo-element o'rniga)
                  Positioned(
                    left: -22,
                    top: 25,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(20)),
                        boxShadow: [BoxShadow(color: bgColor, offset: const Offset(2, -10))],
                      ),
                    ),
                  ),
                  // O'ng yon tomondagi bukilgan qism
                  Positioned(
                    right: -22,
                    top: 25,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
                        boxShadow: [BoxShadow(color: bgColor, offset: const Offset(-2, -10))],
                      ),
                    ),
                  ),
                  // Asosiy harakatlanuvchi pufakcha (oq doira)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: navColor, width: 5),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Ikonkalar va Yozuvlar (HTML'dagi <ul> <li> ro'yxati)
            Row(
              children: List.generate(navItems.length, (index) {
                final bool isActive = _currentIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() => _currentIndex = index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: itemWidth,
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ikonka (aktiv — yashil, noaktiv — oq/opacity)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.fastOutSlowIn,
                          top: isActive ? -12 : 22,
                          child: Icon(
                            isActive ? navItems[index]['activeIcon'] : navItems[index]['icon'],
                            color: isActive ? activeIconColor : _inactiveIconColor,
                            size: 26,
                          ),
                        ),
                        // Yozuv (aktiv — yashil, noaktiv — oq/opacity)
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.fastOutSlowIn,
                          bottom: isActive ? 12 : -20,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: isActive ? 1.0 : 0.0,
                            child: Text(
                              navItems[index]['label'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isActive ? activeIconColor : _inactiveLabelColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
