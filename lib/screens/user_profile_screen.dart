import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; // <--- MANA SHU IMPORT YETISHMAYOTGAN EDI
// 1. Faylning tepasida import qiling:
import 'manage_users_screen.dart';


class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserProfileScreen({super.key, this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic> _profileData = {};

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _profileData = widget.user!;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 1. PROFILNI TAHRIRLASH ---
  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _profileData['full_name'] ?? "");
    final phoneController = TextEditingController(text: _profileData['phone'] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Profilni Tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "To'liq Ism", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 10),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telefon raqam", prefixIcon: Icon(Icons.phone))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              try {
                final userId = _supabase.auth.currentUser!.id;
                await _supabase.from('profiles').update({
                  'full_name': nameController.text,
                  'phone': phoneController.text,
                }).eq('id', userId);
                
                Navigator.pop(ctx);
                _loadProfile(); // Yangilash
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ma'lumotlar saqlandi!"), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SAQLASH"),
          )
        ],
      ),
    );
  }

  // --- 2. PAROLNI O'ZGARTIRISH ---
  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Parolni o'zgartirish"),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: "Yangi parol (min 6 ta belgi)", prefixIcon: Icon(Icons.lock)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parol juda qisqa!")));
                return;
              }
              try {
                await _supabase.auth.updateUser(UserAttributes(password: passwordController.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parol muvaffaqiyatli o'zgartirildi!"), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("O'ZGARTIRISH"),
          )
        ],
      ),
    );
  }
// 2. Tugma yasang (agar profil _userRole == 'admin' bo'lsa ko'rinadi):
if (_userRole == 'admin') ...[
  const Divider(),
  ListTile(
    leading: const Icon(Icons.admin_panel_settings, color: Colors.redAccent),
    title: const Text("Xodimlarni Boshqarish"),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
    },
  ),
]

  // --- 3. TIZIMDAN CHIQISH ---
  void _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      // Login ekraniga to'g'ri qaytarish
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()), 
        (route) => false
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bazadan kelgan ma'lumotlar
    final String fullName = _profileData['full_name'] ?? "Foydalanuvchi";
    final String role = (_profileData['role'] ?? "worker").toString().toUpperCase();
    final String email = _supabase.auth.currentUser?.email ?? "Email yo'q";
    final String phone = _profileData['phone'] ?? "+998 -- --- -- --";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Profil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER KARTA ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Colors.blue.shade50,
                          child: Icon(Icons.person, size: 40, color: Colors.blue.shade900),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(role, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showEditProfileDialog,
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text("Tahrirlash"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- MENU RO'YXATI ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        _buildMenuTile(Icons.notifications_none, "Bildirishnomalar", () {}),
                        const Divider(height: 1),
                        _buildMenuTile(Icons.vpn_key_outlined, "Parolni o'zgartirish", _showChangePasswordDialog),
                        const Divider(height: 1),
                        _buildMenuTile(Icons.security, "Xavfsizlik", () {}),
                        const Divider(height: 1),
                        _buildMenuTile(Icons.help_outline, "Qo'llab-quvvatlash", () {}),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- TIZIMDAN CHIQISH TUGMASI ---
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.power_settings_new, color: Colors.red),
                      label: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.red.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                  const Text("Shaxsiy Ma'lumotlar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                  const SizedBox(height: 10),

                  // --- SHAXSIY MA'LUMOTLAR RO'YXATI ---
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        _buildInfoTile(Icons.person_outline, "To'liq ismi", fullName),
                        const Divider(height: 1, indent: 50),
                        _buildInfoTile(Icons.email_outlined, "Elektron pochta", email),
                        const Divider(height: 1, indent: 50),
                        _buildInfoTile(Icons.phone_outlined, "Telefon raqam", phone),
                        const Divider(height: 1, indent: 50),
                        _buildInfoTile(Icons.location_on_outlined, "Manzil", _profileData['address'] ?? "O'zbekiston"),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
