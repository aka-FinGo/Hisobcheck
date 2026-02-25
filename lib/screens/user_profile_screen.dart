import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId; 
  const UserProfileScreen({super.key, this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isMe = false;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _isMe = widget.userId == null || widget.userId == _supabase.auth.currentUser!.id;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final String targetId = widget.userId ?? _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('profiles')
          .select('*, app_roles(*)')
          .eq('id', targetId)
          .single();
      setState(() => _userData = response);
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null || amount == 0) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  // 1. TAHRIRLASH DIALOGI
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userData!['full_name']);
    final phoneCtrl = TextEditingController(text: _userData!['phone']);
    final tgCtrl = TextEditingController(text: _userData!['telegram_username'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ma'lumotlarni tahrirlash"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "To'liq ism")),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon"), keyboardType: TextInputType.phone),
              TextField(controller: tgCtrl, decoration: const InputDecoration(labelText: "Telegram", prefixText: "@")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('profiles').update({
                'full_name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'telegram_username': tgCtrl.text.replaceAll('@', ''),
              }).eq('id', _userData!['id']);
              Navigator.pop(ctx);
              _loadData();
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final themeProvider = Provider.of<ThemeProvider>(context);
    final bool isSuper = _userData!['is_super_admin'] == true;
    final String fullName = _userData!['full_name'] ?? 'Ismsiz';
    final roleData = _userData!['app_roles'];
    final bool isAup = roleData != null && roleData['role_type'] == 'aup';

    // Moliya hisob-kitobi
    double myBaseSalary = 0;
    double myBonusPerM2 = 0;
    if (isAup) {
      myBaseSalary = (_userData!['custom_salary'] ?? roleData['base_salary'] ?? 0).toDouble();
      myBonusPerM2 = (_userData!['custom_bonus_per_m2'] ?? roleData['bonus_per_m2'] ?? 0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isMe ? "Profilim" : "Xodim Profili"), centerTitle: true, elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // --- HEADER ---
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: isSuper ? Colors.amber.withOpacity(0.2) : const Color(0xFF2E5BFF).withOpacity(0.1),
                  child: Text(fullName[0].toUpperCase(), style: TextStyle(fontSize: 30, color: isSuper ? Colors.amber : const Color(0xFF2E5BFF), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(roleData?['name'] ?? 'Lavozimsiz', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // --- MOLIYA VA SHARTLAR ---
          _buildSectionTitle("MOLIYA VA SHARTLAR"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isSuper 
                ? const Row(children: [Icon(Icons.diamond, color: Colors.amber), SizedBox(width: 10), Text("Korxona Rahbari (Superadmin)")])
                : (isAup 
                    ? Column(
                        children: [
                          _buildInfoRow("Asosiy oylik:", _formatMoney(myBaseSalary), Colors.green),
                          const Divider(),
                          _buildInfoRow("Kvadrat bonusi:", "${_formatMoney(myBonusPerM2)} / m²", Colors.blue),
                        ],
                      )
                    : const Row(children: [Icon(Icons.engineering, color: Colors.orange), SizedBox(width: 10), Text("Ishbay (Tarif bo'yicha) haq oladi")])),
            ),
          ),
          const SizedBox(height: 20),

          // --- ILOVA DIZAYNI (Theme Buttons) ---
          if (_isMe) ...[
            _buildSectionTitle("ILOVA DIZAYNI"),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildThemeBtn(themeProvider, AppThemeMode.light, "Oq", Icons.light_mode_rounded, Colors.blueAccent),
                const SizedBox(width: 10),
                _buildThemeBtn(themeProvider, AppThemeMode.dark, "Qora", Icons.dark_mode_rounded, Colors.deepPurpleAccent),
                const SizedBox(width: 10),
                _buildThemeBtn(themeProvider, AppThemeMode.glass, "Oyna", Icons.lens_blur_rounded, Colors.tealAccent),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // --- SOZLAMALAR ---
          _buildSectionTitle("SOZLAMALAR"),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blue),
                  title: const Text("Ma'lumotlarni tahrirlash"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showEditProfileDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset, color: Colors.orange),
                  title: const Text("Parolni yangilash"),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emailingizga havola yuborildi!"))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    await _supabase.auth.signOut();
                    if (mounted) Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
              ],
            ),
          ),

          // --- DANGER ZONE (Admin boshqa xodimni ko'rganda) ---
          if (!_isMe && !isSuper) ...[
            const SizedBox(height: 20),
            _buildSectionTitle("DANGER ZONE"),
            Card(
              color: Colors.red.withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Colors.redAccent)),
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: const Text("Xodimni bloklash", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                onTap: () => _confirmAction("Bloklash"),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildThemeBtn(ThemeProvider provider, AppThemeMode mode, String title, IconData icon, Color color) {
    final isSelected = provider.currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.toggleTheme(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontSize: 12, color: isSelected ? color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmAction(String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text("Haqiqatan ham ushbu amalni bajarmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Yo'q")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text("Ha")),
        ],
      ),
    );
  }
}
