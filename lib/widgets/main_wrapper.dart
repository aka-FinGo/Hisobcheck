import 'dart:ui';
import 'package:flutter/material.dart';

import '../screens/home_screen.dart'; 
import '../screens/clients_screen.dart';
import '../screens/orders_list_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';
import 'custom_bottom_nav.dart'; 
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
      backgroundColor: Colors.transparent, // Asosiy fonni yo'qotamiz
      body: Stack(
        children: [
          // 1-QAVAT: Orqa fon rasmi (Siz yuklagan rasm)
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          // 2-QAVAT: Xiralashtirish (Blur) va qoraytirish
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Blur darajasi
              child: Container(
                color: Colors.black.withOpacity(0.5), // Yozuvlar yaxshi ko'rinishi uchun yarim shaffof qora
              ),
            ),
          ),

          // 3-QAVAT: Asosiy ilova sahifalari
          PageView(
            controller: _controller,
            physics: const NeverScrollableScrollPhysics(), 
            children: const [
              HomeScreen(),         
              ClientsScreen(),      
              OrdersListScreen(),   
              StatsScreen(),        
              UserProfileScreen(),  
            ],
          ),
        ],
      ),
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
