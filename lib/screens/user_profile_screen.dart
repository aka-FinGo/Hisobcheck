import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  final String? userId; // Agar bo'sh bo'lsa - o'zining profili
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

  // Ruxsatnomalar ro'yxati
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

  // TAHRIRLASH DIALOGI (ADMIN UCHUN)
  void _showAdminEditDialog() {
    int? selectedRoleId = _userData!['position_id'];
    Map<String, dynamic> customPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    final salaryCtrl = TextEditingController(text: _userData!['custom_salary']?.toString() ?? '');
    final bonusCtrl = TextEditingController(text: _userData!['custom_bonus_per_m2']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          title: const Text("Xodimni sozlash"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedRoleId,
                  items: _roles.map((r) => DropdownMenuItem<int>(value: r['id'], child: Text(r['name']))).toList(),
                  onChanged: (v) => setST(() => selectedRoleId = v),
                  decoration: const InputDecoration(labelText: "Lavozimi"),
                ),
                const SizedBox(height: 10),
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: "Shaxsiy oylik (fiks)"), keyboardType: TextInputType.number),
                TextField(controller: bonusCtrl, decoration: const InputDecoration(labelText: "Kvadrat bonusi"), keyboardType: TextInputType.number),
                const Divider(),
                const Text("Qo'shimcha ruxsatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._allPerms.entries.map((e) => CheckboxListTile(
                  title: Text(e.value, style: const TextStyle(fontSize: 12)),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final role = _userData!['app_roles'];
    final bool isSuper = _userData!['is_super_admin'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Mening profilim" : "Xodim profili"),
        actions: [
          if (!_isMe && !isSuper) 
            IconButton(onPressed: _showAdminEditDialog, icon: const Icon(Icons.edit_note, size: 30, color: Colors.blue)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profili Header
          Center(
            child: Column(
              children: [
                CircleAvatar(radius: 50, child: Text(_userData!['full_name']?[0] ?? 'U', style: const TextStyle(fontSize: 30))),
                const SizedBox(height: 10),
                Text(_userData!['full_name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(role?['name'] ?? 'Lavozimsiz', style: const TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Maosh Ma'lumotlari
          const Text("Moliya", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Card(
            child: ListTile(
              title: Text("Fiks oylik: ${NumberFormat("#,###").format(_userData!['custom_salary'] ?? role?['base_salary'] ?? 0)} so'm"),
              subtitle: Text("m2 bonusi: ${NumberFormat("#,###").format(_userData!['custom_bonus_per_m2'] ?? role?['bonus_per_m2'] ?? 0)} so'm"),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // DANGER ZONE (Faqat Admin ko'radi boshqalar uchun)
          if (!_isMe && !isSuper) ...[
            const Text("Danger Zone", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            Card(
              color: Colors.red.withOpacity(0.05),
              child: ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Xodimni bloklash", style: TextStyle(color: Colors.red)),
                onTap: () {
                  // Bloklash mantiqi (masalan statusni 'blocked' qilish)
                },
              ),
            ),
          ],
          
          if (_isMe) 
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50),
                onPressed: () => _supabase.auth.signOut(), 
                child: const Text("Chiqish", style: TextStyle(color: Colors.red)),
              ),
            ),
        ],
      ),
    );
  }
}
