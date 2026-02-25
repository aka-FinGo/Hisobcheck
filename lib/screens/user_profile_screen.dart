import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../theme/theme_provider.dart'; // Yo'l to'g'ri ekanligiga ishonch hosil qiling

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
    // Agar userId null bo'lsa yoki joriy userga teng bo'lsa - demak bu "Mening profilim"
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

  // ─── TAHRIRLASH DIALOGI (iPhone Style) ────────────────────────
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userData!['full_name']);
    final phoneCtrl = TextEditingController(text: _userData!['phone']);
    final tgCtrl = TextEditingController(text: _userData!['telegram_username'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Ma'lumotlarni tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "To'liq ism")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon"), keyboardType: TextInputType.phone),
            TextField(controller: tgCtrl, decoration: const InputDecoration(labelText: "Telegram username", prefixText: "@")),
          ],
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

    final bool isSuper = _userData!['is_super_admin'] == true;
    final String fullName = _userData!['full_name'] ?? 'Ismsiz';
    final roleData = _userData!['app_roles'];
    final String position = roleData != null ? roleData['name'] : 'Lavozimsiz';
    final bool isAup = roleData != null && roleData['role_type'] == 'aup';

    // Oylikni hisoblash (Shaxsiy ustun tursa o'shani, yo'qsa standartni oladi)
    double myBaseSalary = 0;
    double myBonusPerM2 = 0;
    if (isAup) {
      myBaseSalary = (_userData!['custom_salary'] ?? roleData['base_salary'] ?? 0).toDouble();
      myBonusPerM2 = (_userData!['custom_bonus_per_m2'] ?? roleData['bonus_per_m2'] ?? 0).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Profilim" : "Xodim Profili"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. HEADER (Avatar va Ism)
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: isSuper ? Colors.amber.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
                  child: Text(fullName[0].toUpperCase(), style: TextStyle(fontSize: 32, color: isSuper ? Colors.amber : Colors.blue)),
                ),
                const SizedBox(height: 12),
                Text(fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(position, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // 2. MOLIYAVIY SHARTLAR (Eski funksionallik qaytarildi)
          const Text("MOLIYA VA SHARTLAR", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isSuper 
                ? const Row(children: [Icon(Icons.diamond, color: Colors.amber), SizedBox(width: 10), Text("Tizim asoschisi")])
                : (isAup 
                    ? Column(
                        children: [
                          _buildSalaryRow("Fiks oylik:", _formatMoney(myBaseSalary)),
                          const Divider(),
                          _buildSalaryRow("Bonus (m² uchun):", _formatMoney(myBonusPerM2)),
                        ],
                      )
                    : const Text("Ishbay (Tarif bo'yicha) hisoblanadi")),
            ),
          ),
          const SizedBox(height: 25),

          // 3. SOZLAMALAR (iPhone Style)
          const Text("SOZLAMALAR", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blue),
                  title: const Text("Ma'lumotlarni tahrirlash"),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _showEditProfileDialog,
                ),
                if (_isMe) ...[
                  const Divider(height: 1, indent: 55),
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined, color: Colors.purple),
                    title: const Text("Tungi rejim"),
                    trailing: Switch.adaptive(
                      value: Theme.of(context).brightness == Brightness.dark,
                      onChanged: (val) {
                        Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                      },
                    ),
                  ),
                ],
                const Divider(height: 1, indent: 55),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.green),
                  title: const Text("Parolni yangilash"),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emailga havola yuborildi!"))),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 25),

          // 4. DANGER ZONE (Faqat Admin boshqa xodim uchun ko'radi)
          if (!_isMe && !isSuper) ...[
            const Text("XAVFLI HUDUD", style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.red.withOpacity(0.05),
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Xodimni bloklash", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () => _confirmAction("Bloklash"),
              ),
            ),
          ],

          if (_isMe)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: TextButton(
                onPressed: () => _supabase.auth.signOut(),
                child: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        ],
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
