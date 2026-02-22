import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'login_screen.dart';
import 'admin_panel_screen.dart';
import '../theme/theme_provider.dart';

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
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil"),
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

                const Padding(
                  padding: EdgeInsets.only(left: 5, bottom: 10),
                  child: Text(
                    "Ilova dizayni",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                ),
                Row(
                  children: [
                    _buildThemeButton(
                      context,
                      provider: themeProvider,
                      mode: AppThemeMode.light,
                      title: "Oq",
                      icon: Icons.light_mode_rounded,
                      activeColor: Colors.blueAccent,
                    ),
                    const SizedBox(width: 10),
                    _buildThemeButton(
                      context,
                      provider: themeProvider,
                      mode: AppThemeMode.dark,
                      title: "Qora",
                      icon: Icons.dark_mode_rounded,
                      activeColor: Colors.deepPurpleAccent,
                    ),
                    const SizedBox(width: 10),
                    _buildThemeButton(
                      context,
                      provider: themeProvider,
                      mode: AppThemeMode.glass,
                      title: "Oyna",
                      icon: Icons.lens_blur_rounded,
                      activeColor: Colors.tealAccent,
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.phone),
                        title: Text(_userPhone.isEmpty ? "Raqam kiritilmagan" : _userPhone),
                      ),
                      Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                      
                      if (_userRole == 'admin') ...[
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
                          title: const Text("Admin Panel", style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text("Boshqaruv markaziga kirish"),
                          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                          },
                        ),
                        Divider(height: 1, color: Colors.grey.withOpacity(0.2)),
                      ],
                      
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.redAccent),
                        title: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.redAccent)),
                        onTap: _logout,
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildThemeButton(
    BuildContext context, {
    required ThemeProvider provider,
    required AppThemeMode mode,
    required String title,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = provider.currentMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => provider.toggleTheme(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected 
                ? activeColor.withOpacity(0.15) 
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? activeColor : (isDark ? Colors.white24 : Colors.grey.shade300),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon, 
                color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey), 
                size: 28
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.grey.shade800),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
