import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/remnant_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/clients_screen.dart';
class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  // Sahifalar ro'yxati
  final List<Widget> _pages = [
    const HomeScreen(),
    const HistoryScreen(),
    const RemnantScreen(),
    const ClientsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue.shade900,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Asosiy'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Tarix'),
          BottomNavigationBarItem(icon: Icon(Icons.layers), label: 'Qoldiqlar'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Mijozlar'),
        ],
      ),
    );
  }
}
