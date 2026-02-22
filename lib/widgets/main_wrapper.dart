import 'package:flutter/material.dart';
import 'package:rolling_bottom_bar/rolling_bottom_bar.dart';
import 'package:rolling_bottom_bar/rolling_bottom_bar_item.dart';

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
  // PageView ni boshqarish uchun Controller
  final _controller = PageController();

  @override
  void initState() {
    super.initState();
    // Ilova ochilgach, agar PWA o'rnatilmagan bo'lsa eslatish
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
      // Sahifalar ro'yxati (Endi IndexedStack emas, PageView ishlatiladi)
            // Barcha sahifalarni pastdan 100 piksel tepaga surib turadigan global qobiq
      body: Padding(
        padding: const EdgeInsets.only(bottom: 100.0), // Menyu balandligiga mos bo'sh joy
        child: PageView(
          controller: _controller,
          physics: const NeverScrollableScrollPhysics(), 
          children: const <Widget>[
            HomeScreen(),         // 0
            ClientsScreen(),      // 1
            OrdersListScreen(),   // 2
            StatsScreen(),        // 3
            UserProfileScreen(),  // 4
          ],
        ),
      ),

      
      extendBody: true, // Menyu sahifaning ustida chiroyli turishi (suzishi) uchun kerak
      
      // Siz xohlagan aylanuvchi Bottom Navigation Bar
      bottomNavigationBar: RollingBottomBar(
        controller: _controller,
        flat: true,
        useActiveColorByDefault: false,
        items: const [
          RollingBottomBarItem(Icons.home_rounded, label: 'Asosiy', activeColor: Color(0xFF2E5BFF)),
          RollingBottomBarItem(Icons.people_alt_rounded, label: 'Mijozlar', activeColor: Color(0xFF2E5BFF)),
          RollingBottomBarItem(Icons.list_alt_rounded, label: 'Zakazlar', activeColor: Color(0xFF2E5BFF)),
          RollingBottomBarItem(Icons.bar_chart_rounded, label: 'Hisobot', activeColor: Color(0xFF2E5BFF)),
          RollingBottomBarItem(Icons.settings_rounded, label: 'Profil', activeColor: Color(0xFF2E5BFF)),
        ],
        enableIconRotation: true, // Ikonkalarning aylanish animatsiyasi
        onTap: (index) {
          _controller.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        },
      ),
    );
  }
}
