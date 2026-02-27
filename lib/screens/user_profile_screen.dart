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

  // Siz aytgan barcha ruxsatnomalar ro'yxati
  final Map<String, String> _allPerms = {
    'can_view_finance': 'Kassani ko\'rish',
    'can_add_order': 'Zakaz qo\'shish',
    'can_manage_users': 'Xodimlarni boshqarish',
    'can_manage_clients': 'Mijozlarni boshqarish',
    'can_add_work_log': 'Ish hisobotini kiritish',
    'can_view_all_orders': 'Barcha zakazlarni ko\'rish',
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
      
      // Profil, Lavozim va Ruxsatlarni bittada tortamiz
      final userRes = await _supabase
          .from('profiles')
          .select('*, app_roles(*)')
          .eq('id', targetId)
          .single();
      
      // Rollar ro'yxati (Dropdown uchun)
      final rolesRes = await _supabase.from('app_roles').select().order('name');

      setState(() {
        _userData = userRes;
        _roles = rolesRes;
      });
    } catch (e) {
      debugPrint("Ma'lumot yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ADMIN UCHUN HODIMNI TO'LIQ SOZLASH DIALOGI ---
  void _showAdminEditDialog() {
    int? selectedRoleId = _userData!['position_id'];
    Map<String, dynamic> customPerms = Map<String, dynamic>.from(_userData!['custom_permissions'] ?? {});
    final salaryCtrl = TextEditingController(text: customPerms['custom_salary']?.toString() ?? '');
    final bonusCtrl = TextEditingController(text: customPerms['custom_bonus_per_m2']?.toString() ?? '');
    final globalBonusCtrl = TextEditingController(text: customPerms['global_bonus_m2']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${_userData!['full_name']} sozlamalari"),
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
                TextField(controller: salaryCtrl, decoration: const InputDecoration(labelText: "Shaxsiy fiks oylik", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: bonusCtrl, decoration: const InputDecoration(labelText: "Kvadrat bonusi (m2)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: globalBonusCtrl, decoration: const InputDecoration(labelText: "Barcha yakunlanganlardan ulush (m2)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const Divider(height: 30),
                const Text("Maxsus ruxsatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                ..._allPerms.entries.map((e) => CheckboxListTile(
                  title: Text(e.value, style: const TextStyle(fontSize: 13)),
                  value: customPerms[e.key] == true,
                  onChanged: (v) {
                    setST(() {
                      if (v == true) {
                        customPerms[e.key] = true;
                      } else {
                        customPerms.remove(e.key);
                      }
                    });
                  },
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                // Yangi qiymatni ruxsatlar ichiga yozamiz
                if (globalBonusCtrl.text.isNotEmpty) {
                  customPerms['global_bonus_m2'] = double.tryParse(globalBonusCtrl.text);
                } else {
                  customPerms.remove('global_bonus_m2');
                }

                try {
                  // Shaxsiy fiks oylik va kvadrat bonusni JSON'ga tiqamiz!
                  if (salaryCtrl.text.isNotEmpty) {
                    customPerms['custom_salary'] = double.tryParse(salaryCtrl.text);
                  } else {
                    customPerms.remove('custom_salary');
                  }

                  if (bonusCtrl.text.isNotEmpty) {
                    customPerms['custom_bonus_per_m2'] = double.tryParse(bonusCtrl.text);
                  } else {
                    customPerms.remove('custom_bonus_per_m2');
                  }

                  await _supabase.from('profiles').update({
                    'position_id': selectedRoleId,
                    'custom_permissions': customPerms,
                  }).eq('id', _userData!['id']);
                  if (mounted) {
                    Navigator.pop(context);
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi!"), backgroundColor: Colors.green));
                  }
                } catch(e) {
                  debugPrint("Profile saqlashda xato: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red));
                  }
                }
                _loadData();
              },
              child: const Text("Saqlash"),
            )
          ],
        ),
      ),
    );
  }
  // --- DAVOMI: UI VA QO'SHIMCHA FUNKSIYALAR ---
  String _formatMoney(dynamic amount) {
    if (amount == null || amount == 0) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  void _showEditInfoDialog() {
    final nameCtrl = TextEditingController(text: _userData!['full_name']);
    final phoneCtrl = TextEditingController(text: _userData!['phone']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ma'lumotlar"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ism")),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon")),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('profiles').update({'full_name': nameCtrl.text, 'phone': phoneCtrl.text}).eq('id', _userData!['id']);
              Navigator.pop(ctx); _loadData();
            }, 
            child: const Text("Saqlash")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final themeP = Provider.of<ThemeProvider>(context);
    final role = _userData!['app_roles'];
    final bool isSuper = _userData!['is_super_admin'] == true;
    final bool isAup = role != null && role['role_type'] == 'aup';
    
    final Map<String, dynamic> cPerms = _userData!['custom_permissions'] != null 
        ? Map<String, dynamic>.from(_userData!['custom_permissions']) 
        : {};

    // Moliya mantiqi (Shaxsiy oylik tursa o'sha, JSON ichidan)
    double salary = (cPerms['custom_salary'] ?? role?['base_salary'] ?? 0).toDouble();
    double bonus = (cPerms['custom_bonus_per_m2'] ?? role?['rate_per_unit'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? "Mening profilim" : "Xodim profili"),
        actions: [
          if (!_isMe && !isSuper) 
            IconButton(onPressed: _showAdminEditDialog, icon: const Icon(Icons.edit_note, size: 35, color: Colors.blue)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. HEADER
          Center(
            child: Column(children: [
              CircleAvatar(radius: 50, child: Text(_userData!['full_name']?[0] ?? 'U', style: const TextStyle(fontSize: 32))),
              const SizedBox(height: 10),
              Text(_userData!['full_name'] ?? 'Ismsiz', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(role?['name'] ?? 'Lavozimsiz', style: const TextStyle(color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 30),

          // 2. MOLIYA VA SHARTLAR (To'liq tiklandi)
          const Text("MOLIYA VA SHARTLAR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isSuper 
                ? Column(
                    children: [
                      const Row(children: [Icon(Icons.diamond, color: Colors.amber), SizedBox(width: 10), Text("Tizim Asoschisi (Superadmin)")]),
                      if ((_userData!['custom_permissions']?['global_bonus_m2'] ?? 0) > 0) ...[
                        const Divider(height: 25),
                        _infoRow("Umumiy ulush:", "${_formatMoney(_userData!['custom_permissions']['global_bonus_m2'])} / m²"),
                      ]
                    ]
                  )
                : (isAup 
                    ? Column(children: [
                        _infoRow("Fiks oylik:", _formatMoney(salary)),
                        const Divider(height: 25),
                        _infoRow("Kvadrat bonusi:", "${_formatMoney(bonus)} / m²"),
                        if ((_userData!['custom_permissions']?['global_bonus_m2'] ?? 0) > 0) ...[
                          const Divider(height: 25),
                          _infoRow("Umumiy ulush:", "${_formatMoney(_userData!['custom_permissions']['global_bonus_m2'])} / m²"),
                        ]
                      ])
                    : const Row(children: [Icon(Icons.engineering, color: Colors.orange), SizedBox(width: 10), Text("Ishbay (Tarif bo'yicha) hisoblanadi")])),
            ),
          ),
          const SizedBox(height: 30),

          // 3. ILOVA DIZAYNI (3 ta iPhone Style tugma)
          if (_isMe) ...[
            const Text("ILOVA DIZAYNI", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Row(children: [
              _themeB(themeP, AppThemeMode.light, "Oq", Icons.light_mode, Colors.blue),
              const SizedBox(width: 10),
              _themeB(themeP, AppThemeMode.dark, "Qora", Icons.dark_mode, Colors.deepPurple),
              const SizedBox(width: 10),
              _themeB(themeP, AppThemeMode.glass, "Oyna", Icons.blur_on, Colors.teal),
            ]),
            const SizedBox(height: 30),
          ],

          // 4. SOZLAMALAR
          const Text("SOZLAMALAR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(children: [
              ListTile(leading: const Icon(Icons.person_outline), title: const Text("Ma'lumotlarni tahrirlash"), onTap: _showEditInfoDialog),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red), 
                title: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.red)),
                onTap: () => _supabase.auth.signOut(),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.grey)), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green))]);

  Widget _themeB(ThemeProvider p, AppThemeMode m, String t, IconData i, Color c) {
    final sel = p.currentMode == m;
    return Expanded(child: GestureDetector(
      onTap: () => p.toggleTheme(m),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: sel ? c.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? c : Colors.grey.withOpacity(0.3)),
        ),
        child: Column(children: [Icon(i, color: sel ? c : Colors.grey), Text(t, style: TextStyle(fontSize: 12, color: sel ? c : Colors.grey))]),
      ),
    ));
  }
}
