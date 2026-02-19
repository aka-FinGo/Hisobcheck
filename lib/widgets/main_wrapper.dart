import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/home_screen.dart';
import '../screens/clients_screen.dart';
import '../screens/user_profile_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  bool _isLoading = true;
  
  // Sahifalar ro'yxati oldindan bo'sh turadi
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  // 🔴 KRITIK TUZATISH: Async muammosi hal qilindi
  Future<void> _initApp() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Profil ma'lumotlarini kutamiz
      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();

      if (mounted) {
        setState(() {
          // Barcha sahifalar to'liq ma'lumot bilan initsializatsiya qilinadi
          _pages = [
            const HomeScreen(),
            const ClientsScreen(),
            UserProfileScreen(user: profile), // Profil ma'lumoti uzatildi
          ];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("MainWrapper init xatosi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _pages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue.shade900,
        unselectedItemColor: Colors.grey,
        // 🟡 O'RTA DARAJALI TUZATISH: Cheksiz loop yo'q qilindi
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Asosiy"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Mijozlar"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
    );
  }
}
