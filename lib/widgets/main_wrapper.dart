import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- MUHIM: Sahifalar "screens" papkasida bo'lgani uchun yo'lni to'g'irladik ---
import '../screens/home_screen.dart';
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

  // Sahifalar ro'yxati
  List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _setupRoleAndPages();
  }

  Future<void> _setupRoleAndPages() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('profiles').select('role').eq('id', user.id).single();
      _userRole = data['role'] ?? 'worker';
    }

    // Rolga qarab sahifalarni yig'amiz
    if (_userRole == 'admin' || _userRole == 'owner') {
      _pages = [
        const HomeScreen(),          // 0: Uy
        const StatsScreen(),         // 1: Statistika
        const ManageUsersScreen(),   // 2: Xodimlar
        // Profil uchun ma'lumotni fetch qilamiz
        UserProfileScreen(user: await _fetchFullProfile(user!.id)), // 3: Profil
      ];
    } else {
      _pages = [
        const HomeScreen(),          // 0: Uy
        UserProfileScreen(user: await _fetchFullProfile(user!.id)), // 1: Profil
      ];
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // Profil uchun to'liq ma'lumot olish yordamchisi
  Future<Map<String, dynamic>> _fetchFullProfile(String userId) async {
    return await _supabase.from('profiles').select().eq('id', userId).single();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      // IndexedStack ishlatamiz - bu sahifalar holatini saqlab qoladi
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      
      // --- PASTKI MENYU (MIXLANGAN QISM) ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed, // 4 tadan ko'p bo'lsa ham joyida turadi
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue.shade900,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          elevation: 0,
          items: _buildNavItems(),
        ),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    if (_userRole == 'admin' || _userRole == 'owner') {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: "Statistika"),
        BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: "Xodimlar"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profil"),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: "Profil"),
      ];
    }
  }
}