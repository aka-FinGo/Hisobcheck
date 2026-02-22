import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';

// --- EKRANLAR IMPORTI ---
import '../screens/home_screen.dart'; 
import '../screens/clients_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';

// PWA oynasi uchun
import 'pwa_prompt.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _currentIndex = 0;
  final PageController _controller = PageController();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      // Scaffold endi menyu balandligini o'zi hisoblaydi, 
      // yozuvlar menyu tagida qolib ketmaydi!
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(), // Ekranlarni qo'lda surishni bloklash
        children: const [
          HomeScreen(),         // 0
          ClientsScreen(),      // 1
          OrdersListScreen(),   // 2
          StatsScreen(),        // 3
          UserProfileScreen(),  // 4
        ],
      ),
      bottomNavigationBar: Container(
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
            // Menyuning ikki chekkasidagi bo'shliq
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: GNav(
              rippleColor: Colors.grey[300]!,
              hoverColor: Colors.grey[100]!,
              gap: 8, // Ikonka va yozuv o'rtasidagi masofa
              activeColor: const Color(0xFF2E5BFF), // Faol bo'lgandagi ikonka/yozuv rangi (Ko'k)
              iconSize: 26,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: const Color(0xFF2E5BFF).withOpacity(0.1), // Faol tugma foni (Och ko'k)
              color: Colors.grey[600]!, // Faol bo'lmagan ikonkalar rangi (Kulrang)
              tabs: const [
                GButton(icon: Icons.home_rounded, text: 'Asosiy'),
                GButton(icon: Icons.people_alt_rounded, text: 'Mijozlar'),
                GButton(icon: Icons.list_alt_rounded, text: 'Zakazlar'),
                GButton(icon: Icons.bar_chart_rounded, text: 'Hisobot'),
                GButton(icon: Icons.person_rounded, text: 'Profil'),
              ],
              selectedIndex: _currentIndex,
              onTabChange: (index) {
                setState(() {
                  _currentIndex = index;
                });
                // Tugma bosilganda sahifani almashtirish
                _controller.jumpToPage(index); 
              },
            ),
          ),
        ),
      ),
    );
  }
}
