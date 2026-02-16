import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- DIQQAT: Importlar to'g'rilandi (screens papkasidan olinadi) ---
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
    _checkRoleAndSetup();
  }

  Future<void> _checkRoleAndSetup() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('profiles').select('role').eq('id', user.id).single();
      _userRole = data['role'] ?? 'worker';
    }

    // Rolga qarab sahifalarni belgilaymiz
    if (_userRole == 'admin' || _userRole == 'owner') {
      _pages = [
        const HomeScreen(),          // 0: Uy
        const StatsScreen(),         // 1: Statistika (Faqat adminda)
        const ManageUsersScreen(),   // 2: Xodimlar (Faqat adminda)
        _buildProfilePage(user!),    // 3: Profil
      ];
    } else {
      // Oddiy ishchi uchun menyu
      _pages = [
        const HomeScreen(),          // 0: Uy
        _buildProfilePage(user!),    // 1: Profil
      ];
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Profil sahifasini qurish uchun yordamchi
  Widget _buildProfilePage(User user) {
    return FutureBuilder(
      future: _supabase.from('profiles').select().eq('id', user.id).single(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        return UserProfileScreen(user: snapshot.data!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
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
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Statistika"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "Xodimlar"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      ];
    } else {
      return const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Asosiy"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
      ];
    }
  }
}