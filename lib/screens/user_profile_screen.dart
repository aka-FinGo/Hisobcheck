import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importlar
import 'login_screen.dart';
import 'admin_panel_screen.dart'; // Faqat Admin Panelni chaqiramiz

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  String _userName = '';
  String _userRole = 'worker';
  String _userPhone = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select().eq('id', user.id).single();
        if (mounted) {
          setState(() {
            _userName = data['full_name'] ?? 'Ism kiritilmagan';
            _userRole = data['role'] ?? 'worker';
            _userPhone = data['phone'] ?? 'Raqam kiritilmagan';
          });
        }
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text("Profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Color(0xFF2E5BFF),
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  _userName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Rol: ${_userRole.toUpperCase()}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone, color: Color(0xFF2E5BFF)),
                        title: Text(_userPhone.isEmpty ? "Raqam kiritilmagan" : _userPhone),
                      ),
                      const Divider(height: 1),
                      
                      // FAQAT ADMINLAR UCHUN ADMIN PANEL TUGMASI
                      if (_userRole == 'admin') ...[
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                          title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Boshqaruv markaziga kirish"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.red)),
                        onTap: _logout,
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
