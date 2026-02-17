import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Barcha sahifalarni import qilamiz ---
import '../screens/home_screen.dart';
import '../screens/clients_screen.dart'; // <--- YANGI QO'SHILDI
import '../screens/stats_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/manage_users_screen.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  String _userRole = 'worker';
  bool _isLoading = true;
  String _currentUserId = '';

  // Sahifalar va ularning nomlari
  List<Widget> _pages = [];
  List<String> _titles = [];

  @override
  void initState() {
    super.initState();
    _setupRoleAndPages();
  }

  Future<void> _setupRoleAndPages() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _currentUserId = user.id;
      final data = await _supabase.from('profiles').select('role').eq('id', user.id).single();
      _userRole = data['role'] ?? 'worker';
    }

    // --- MENYU TARKIBINI TUZAMIZ ---
    if (_userRole == 'admin' || _userRole == 'owner') {
      // ADMIN UCHUN:
      _pages = [
        const HomeScreen(),          // 0: Asosiy
        const ClientsScreen(),       // 1: Mijozlar va Zakazlar (YANGI)
        const ManageUsersScreen(),   // 2: Xodimlar
        UserProfileScreen(user: await _fetchFullProfile(_currentUserId)), // 3: Profil
      ];
      _titles = ["Bosh Sahifa", "Mijozlar va Zakazlar", "Xodimlar", "Mening Profilim"];
    } else {
      // ISHCHI UCHUN:
      _pages = [
        const HomeScreen(),          // 0: Asosiy
        const ClientsScreen(),       // 1: Loyihalarim (Ular ham ko'rsin)
        UserProfileScreen(user: await _fetchFullProfile(_currentUserId)), // 2: Profil
      ];
      _titles = ["Ish Stoli", "Loyihalar", "Profil"];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<Map<String, dynamic>> _fetchFullProfile(String userId) async {
    return await _supabase.from('profiles').select().eq('id', userId).single();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      // --- 1. HEADER (TEPA QISM) ---
      // Agar har bir sahifada o'zining AppBar-i bo'lsa, bu yerni olib tashlang.
      // Lekin siz "Header mixlangan bo'lsin" dedingiz, shuning uchun bu yerda qoldiramiz.
      // DIQQAT: Child sahifalardan (HomeScreen, ClientsScreen) Scaffold va AppBarni olib tashlash tavsiya etiladi,
      // aks holda ikkita Header paydo bo'lib qoladi.
      // Hozircha oddiy yechim sifatida body ichida sahifalar o'z headeri bilan chiqadi,
      // lekin BottomNav joyida qoladi.
      
      // body qismi
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),

      // --- 2. BOTTOM NAV (PASTKI MENYU) ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
              // Agar Profil sahifasiga o'tsa, ma'lumotni yangilash uchun qayta yuklash mumkin
              if (_pages[index] is UserProfileScreen) {
                _setupRoleAndPages(); 
              }
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue.shade900,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: _buildNavItems(),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    if (_userRole == 'admin' || _userRole == 'owner') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.folder_shared), label: "Mijozlar"), // <---
        BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: "Xodimlar"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.folder_shared), label: "Loyihalar"), // <---
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      ];
    }
  }
}
