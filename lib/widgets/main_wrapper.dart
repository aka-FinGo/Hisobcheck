import 'package:flutter/material.dart';

// --- EKRANLAR IMPORTI ---
import '../screens/home_screen.dart'; 
import '../screens/clients_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';

// --- VIDJETLAR ---
import 'custom_bottom_nav.dart'; // O'zimiz yasagan menyuni chaqirib oldik
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
      body: PageView(
        controller: _controller,
        physics: const NeverScrollableScrollPhysics(), 
        children: const [
          HomeScreen(),         // 0
          ClientsScreen(),      // 1
          OrdersListScreen(),   // 2
          StatsScreen(),        // 3
          UserProfileScreen(),  // 4
        ],
      ),
      // Bitta qator bilan butun boshli menyuni ulab qo'ydik!
      bottomNavigationBar: CustomBottomNav(
        selectedIndex: _currentIndex,
        onTabChange: (index) {
          setState(() {
            _currentIndex = index;
          });
          _controller.jumpToPage(index); 
        },
      ),
    );
  }
}
