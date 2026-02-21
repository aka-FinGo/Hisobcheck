import 'package:flutter/material.dart';

// --- EKRANLAR IMPORTI ---
import '../screens/home_screen.dart'; 
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

  // Sahifalar ro'yxati
  final List<Widget> _pages = const [
    HomeScreen(),         // 0 - Asosiy
    ClientsScreen(),      // 1 - Mijozlar
    OrdersListScreen(),   // 2 - Buyurtmalar
    StatsScreen(),        // 3 - Hisobotlar
    UserProfileScreen(),  // 4 - Profil
  ];

  // Ranglar
  final Color bgColor = const Color(0xFFF8F9FE); 
  final Color navColor = Colors.white;           
  final Color activeColor = const Color(0xFF29fd53); // Yashil rang

  // Ikonkalar ro'yxati
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double itemWidth = screenWidth / navItems.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.fastOutSlowIn,
              top: -25, 
              left: (_currentIndex * itemWidth) + (itemWidth - 60) / 2, 
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
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
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: activeColor, 
                      shape: BoxShape.circle,
                      border: Border.all(color: bgColor, width: 6), 
                    ),
                  ),
                ],
              ),
            ),
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
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.fastOutSlowIn,
                          top: isActive ? -12 : 22, 
                          child: Icon(
                            isActive ? navItems[index]['activeIcon'] : navItems[index]['icon'],
                            color: isActive ? Colors.white : Colors.grey.shade600,
                            size: 26,
                          ),
                        ),
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
                                color: Colors.grey.shade800,
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
