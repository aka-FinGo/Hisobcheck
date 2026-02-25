import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // Theme uchun
import '../providers/theme_provider.dart'; // Sizda bor deb hisoblaymiz

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

  // ─── TAHRIRLASH DIALOGI (iPhone Style) ────────────────────────
  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userData!['full_name']);
    final phoneCtrl = TextEditingController(text: _userData!['phone']);
    final tgCtrl = TextEditingController(text: _userData!['telegram_username'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ma'lumotlarni tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "To'liq ism")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon")),
            TextField(controller: tgCtrl, decoration: const InputDecoration(labelText: "Telegram (username)", prefixText: "@")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
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
    final String position = _userData!['app_roles']?['name'] ?? 'Lavozimsiz';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Profilim" : "Xodim Profili"),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. TEPADAGI QISM (Avatar va Ism)
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

          // 2. SOZLAMALAR QATORI (iPhone uslubida)
          const Text("SOZLAMALAR", style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                // 1-TUGMA: Ma'lumotlarni o'zgartirish
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.blue),
                  title: const Text("Ma'lumotlarni tahrirlash"),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: _showEditProfileDialog,
                ),
                const Divider(height: 1, indent: 55),
                
                // 2-TUGMA: Tungi rejim (iPhone Switch)
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
                const Divider(height: 1, indent: 55),

                // 3-TUGMA: Parolni o'zgartirish
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: Colors.green),
                  title: const Text("Parolni yangilash"),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    // Supabase password reset mantiqi shu yerga ulanadi
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emailingizga havola yuborildi!")));
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 25),

          // 3. DANGER ZONE
          if (!_isMe && !isSuper) ...[
            const Text("XAVFLI HUDUD", style: TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              color: Colors.red.withOpacity(0.05),
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Xodimni bloklash", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  // Bloklash tasdiqlash dialogi
                },
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
}
