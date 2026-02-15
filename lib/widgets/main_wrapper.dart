import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/remnant_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  // --- [ 1. HOZIRGI SAHIFA INDEKSI ] ---
  int _selectedIndex = 0;

  // --- [ 2. SAHIFALAR RO'YXATI ] ---
  final List<Widget> _pages = [
    const HomeScreen(),     // Indeks 0: Asosiy oyna
    const HistoryScreen(),  // Indeks 1: Ishlar tarixi
    const RemnantScreen(),  // Indeks 2: LDSP Qoldiqlar
    const WalletScreen(),   // Indeks 3: Shaxsiy hamyon
  ];

  // --- [ 3. SAHIFANI O'ZGARTIRISH FUNKSIYASI ] ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- 2-QISM (UI) PASTDA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tanlangan sahifani ko'rsatish
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),

      // --- [ 4. PASTKI MENYU DIZAYNI ] ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // 4 tadan ko'p tugma bo'lsa shart
        selectedItemColor: Colors.blue.shade900,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Asosiy',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'Tarix',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Qoldiqlar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Hamyon',
          ),
        ],
      ),
    );
  }
}

