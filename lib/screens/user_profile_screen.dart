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

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final String targetId = widget.userId ?? _supabase.auth.currentUser!.id;
      final userRes = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', targetId).single();
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

  void _showAdminEditDialog() {
    int? selId = _userData!['position_id'];
    Map<String, dynamic> cPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    final salCtrl = TextEditingController(text: _userData!['custom_salary']?.toString() ?? '');
    final bonCtrl = TextEditingController(text: _userData!['custom_bonus_per_m2']?.toString() ?? '');

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
                  value: selId,
                  items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name']))).toList(),
                  onChanged: (v) => setST(() => selId = v),
                  decoration: const InputDecoration(labelText: "Lavozimi", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(controller: salCtrl, decoration: const InputDecoration(labelText: "Shaxsiy oylik"), keyboardType: TextInputType.number),
                TextField(controller: bonCtrl, decoration: const InputDecoration(labelText: "Kvadrat bonusi"), keyboardType: TextInputType.number),
                const Divider(height: 30),
                const Text("Maxsus ruxsatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._allPerms.entries.map((e) => CheckboxListTile(
                  title: Text(e.value), value: cPerms[e.key] ?? false,
                  onChanged: (v) => setST(() => cPerms[e.key] = v),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('profiles').update({
                  'position_id': selId,
                  'custom_salary': double.tryParse(salCtrl.text),
                  'custom_bonus_per_m2': double.tryParse(bonCtrl.text),
                  'custom_permissions': cPerms,
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

  String _format(dynamic n) => NumberFormat("#,###").format(n ?? 0).replaceAll(',', ' ') + " so'm";

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final themeP = Provider.of<ThemeProvider>(context);
    final role = _userData!['app_roles'];
    final bool isSuper = _userData!['is_super_admin'] == true;
    final bool isAup = role?['role_type'] == 'aup';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Mening profilim" : "Xodim profili"),
        actions: [if (!_isMe && !isSuper) IconButton(onPressed: _showAdminEditDialog, icon: const Icon(Icons.edit_note, size: 30))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(children: [
              CircleAvatar(radius: 45, child: Text(_userData!['full_name']?[0] ?? 'U', style: const TextStyle(fontSize: 28))),
              const SizedBox(height: 10),
              Text(_userData!['full_name'] ?? 'Ismsiz', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(role?['name'] ?? 'Lavozimsiz', style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 30),
          const Text("MOLIYA VA SHARTLAR", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isSuper ? const Text("Tizim asoschisi") : (isAup ? Column(children: [
                _row("Fiks oylik:", _format(_userData!['custom_salary'] ?? role?['base_salary'])),
                const Divider(),
                _row("m2 bonusi:", _format(_userData!['custom_bonus_per_m2'] ?? role?['bonus_per_m2'])),
              ]) : const Text("Ishbay tarifda")),
            ),
          ),
          const SizedBox(height: 25),
          if (_isMe) ...[
            const Text("ILOVA DIZAYNI", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(children: [
              _btn(themeP, AppThemeMode.light, "Oq", Icons.light_mode, Colors.blue),
              const SizedBox(width: 8),
              _btn(themeP, AppThemeMode.dark, "Qora", Icons.dark_mode, Colors.orange),
              const SizedBox(width: 8),
              _btn(themeP, AppThemeMode.glass, "Oyna", Icons.blur_on, Colors.teal),
            ]),
          ],
          const SizedBox(height: 30),
          if (_isMe) ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red),
            icon: const Icon(Icons.logout), label: const Text("Tizimdan chiqish"),
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
    );
  }

  Widget _row(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]);

  Widget _btn(ThemeProvider p, AppThemeMode m, String t, IconData i, Color c) {
    final sel = p.currentMode == m;
    return Expanded(child: InkWell(
      onTap: () => p.toggleTheme(m),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: sel ? c.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? c : Colors.grey.withOpacity(0.3))),
        child: Column(children: [Icon(i, color: sel ? c : Colors.grey), Text(t, style: TextStyle(color: sel ? c : Colors.grey, fontSize: 12))]),
      ),
    ));
  }
}
