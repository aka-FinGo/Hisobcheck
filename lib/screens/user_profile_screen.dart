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
  List<dynamic> _roles = [];

  // Siz aytgan ruxsatnomalar ro'yxati (Admin uchun)
  final Map<String, String> _allPerms = {
    'can_view_finance': 'Kassani ko\'rish',
    'can_add_order': 'Zakaz qo\'shish',
    'can_manage_users': 'Xodimlarni boshqarish',
    'can_manage_clients': 'Mijozlarni boshqarish',
  };

  @override
  void initState() {
    super.initState();
    _isMe = widget.userId == null || widget.userId == _supabase.auth.currentUser!.id;
    _loadData();
  }

  // ─── MA'LUMOTLARNI YUKLASH (Profil + Rollar) ──────────────────
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final String targetId = widget.userId ?? _supabase.auth.currentUser!.id;
      
      final userRes = await _supabase
          .from('profiles')
          .select('*, app_roles(*)')
          .eq('id', targetId)
          .single();
      
      final rolesRes = await _supabase.from('app_roles').select();

      setState(() {
        _userData = userRes;
        _roles = rolesRes;
      });
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── TAHRIRLASH DIALOGI (ADMIN UCHUN) ─────────────────────────
  void _showAdminEditDialog() {
    int? selectedRoleId = _userData!['position_id'];
    Map<String, dynamic> customPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    final salaryCtrl = TextEditingController(text: _userData!['custom_salary']?.toString() ?? '');
    final bonusCtrl = TextEditingController(text: _userData!['custom_bonus_per_m2']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Xodimni sozlash"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name']))).toList(),
                  onChanged: (v) => setST(() => selectedRoleId = v),
                  decoration: const InputDecoration(labelText: "Lavozimi", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: "Shaxsiy oylik (fiks)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: bonusCtrl, decoration: const InputDecoration(labelText: "Kvadrat bonusi", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const Divider(height: 30),
                const Text("Qo'shimcha ruxsatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._allPerms.entries.map((e) => CheckboxListTile(
                  title: Text(e.value, style: const TextStyle(fontSize: 13)),
                  value: customPerms[e.key] ?? false,
                  onChanged: (v) => setST(() => customPerms[e.key] = v),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('profiles').update({
                  'position_id': selectedRoleId,
                  'custom_salary': double.tryParse(salaryCtrl.text),
                  'custom_bonus_per_m2': double.tryParse(bonusCtrl.text),
                  'custom_permissions': customPerms,
                }).eq('id', _userData!['id']);
                Navigator.pop(context);
                _loadData();
              },
              child: const Text("Saqlash"),
            )
          ],
        ),
      ),
    );
  }
  // ─── DAVOMI: BUILD VA INTERFEYS ──────────────────────────────
  String _formatMoney(dynamic amount) {
    if (amount == null || amount == 0) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final themeProvider = Provider.of<ThemeProvider>(context);
    final role = _userData!['app_roles'];
    final bool isSuper = _userData!['is_super_admin'] == true;
    final String fullName = _userData!['full_name'] ?? 'Ismsiz';
    final bool isAup = role != null && role['role_type'] == 'aup';

    // Moliya hisob-kitobi
    double myBaseSalary = (_userData!['custom_salary'] ?? role?['base_salary'] ?? 0).toDouble();
    double myBonusPerM2 = (_userData!['custom_bonus_per_m2'] ?? role?['bonus_per_m2'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Mening profilim" : "Xodim profili"),
        actions: [
          if (!_isMe && !isSuper) 
            IconButton(onPressed: _showAdminEditDialog, icon: const Icon(Icons.edit_note, size: 30, color: Colors.blue)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // 1. Header
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 50, child: Text(fullName[0].toUpperCase(), style: const TextStyle(fontSize: 32))),
                const SizedBox(height: 12),
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(role?['name'] ?? 'Lavozimsiz', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 2. MOLIYA VA SHARTLAR (Siz aytgan qismlar)
          const Text("MOLIYA VA SHARTLAR", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isSuper 
                ? const Row(children: [Icon(Icons.diamond, color: Colors.amber), SizedBox(width: 10), Text("Tizim asoschisi")])
                : (isAup 
                    ? Column(
                        children: [
                          _buildSalaryRow("Fiks oylik:", _formatMoney(myBaseSalary)),
                          const Divider(height: 25),
                          _buildSalaryRow("Bonus (m² uchun):", _formatMoney(myBonusPerM2)),
                        ],
                      )
                    : const Row(children: [Icon(Icons.engineering, color: Colors.orange), SizedBox(width: 10), Text("Ishbay (Tarif bo'yicha) hisoblanadi")])),
            ),
          ),
          const SizedBox(height: 30),

          // 3. ILOVA DIZAYNI (Theme Buttons)
          if (_isMe) ...[
            const Text("ILOVA DIZAYNI", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildThemeBtn(themeProvider, AppThemeMode.light, "Oq", Icons.light_mode_rounded, Colors.blueAccent),
                const SizedBox(width: 10),
                _buildThemeBtn(themeProvider, AppThemeMode.dark, "Qora", Icons.dark_mode_rounded, Colors.deepPurpleAccent),
                const SizedBox(width: 10),
                _buildThemeBtn(themeProvider, AppThemeMode.glass, "Oyna", Icons.lens_blur_rounded, Colors.tealAccent),
              ],
            ),
            const SizedBox(height: 30),
          ],

          // 4. CHIQISH
          if (_isMe)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15)),
              onPressed: () => _supabase.auth.signOut(), 
              child: const Text("Tizimdan chiqish"),
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
      ],
    );
  }

  Widget _buildThemeBtn(ThemeProvider provider, AppThemeMode mode, String title, IconData icon, Color color) {
    final isSelected = provider.currentMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.toggleTheme(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? color : Colors.grey.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey),
              const SizedBox(height: 5),
              Text(title, style: TextStyle(fontSize: 12, color: isSelected ? color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}
