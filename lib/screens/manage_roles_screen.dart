import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageRolesScreen extends StatefulWidget {
  const ManageRolesScreen({super.key});

  @override
  State<ManageRolesScreen> createState() => _ManageRolesScreenState();
}

class _ManageRolesScreenState extends State<ManageRolesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _roles = [];

  // Tizimdagi barcha mavjud ruxsatlar (rubilniklar) ro'yxati
  final Map<String, String> _availablePermissions = {
    'can_view_finance': 'Kassa va Moliya bo\'limini ko\'rish',
    'can_add_order': 'Yangi zakaz qo\'shish',
    'can_manage_clients': 'Mijozlar bazasini boshqarish',
    'can_manage_users': 'Xodimlar va lavozimlarni boshqarish',
    'can_add_work_log': 'O\'zi bajargan ishlarni kiritish',
    'can_view_all_orders': 'Barcha zakazlarni ko\'rish',
  };

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.from('app_roles').select().order('role_type');
      setState(() => _roles = response);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  // ─── YANGA ROL QO'SHISH YOKI TAHRIRLASH DIALOGI ────────────────
  void _showRoleDialog({Map<String, dynamic>? role}) {
    final isEditing = role != null;
    final nameCtrl = TextEditingController(text: isEditing ? role['name'] : '');
    final baseSalaryCtrl = TextEditingController(text: isEditing ? (role['base_salary'] ?? 0).toString() : '0');
    final bonusPerM2Ctrl = TextEditingController(text: isEditing ? (role['bonus_per_m2'] ?? 0).toString() : '0');
    
    String roleType = isEditing ? role['role_type'] : 'worker';
    
    // Ruxsatlarni Map qilib olamiz
    Map<String, dynamic> currentPermissions = {};
    if (isEditing && role['permissions'] != null) {
      currentPermissions = Map<String, dynamic>.from(role['permissions']);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isAupSelected = roleType == 'aup';

            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isEditing ? "Lavozimni tahrirlash" : "Yangi lavozim yaratish"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Lavozim nomi va Toifasi
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Lavozim nomi (M: Kassir, Qadoqlovchi)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: roleType,
                        decoration: const InputDecoration(labelText: 'Toifasi', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'aup', child: Text('AUP (Boshqaruv, Fiks maosh)')),
                          DropdownMenuItem(value: 'worker', child: Text('Worker (Ishchi, Tarifli)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => roleType = val);
                        },
                      ),
                      const SizedBox(height: 20),

                      // 2. Ish haqi va Bonuslar qismi (Dinamik o'zgaradi)
                      Text("Moliya va Maosh:", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      if (isAupSelected) ...[
                        TextField(
                          controller: baseSalaryCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Fiks oylik maosh', suffixText: "so'm", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: bonusPerM2Ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '1 m² uchun ustama bonus', suffixText: "so'm", border: OutlineInputBorder()),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 20),
                              SizedBox(width: 8),
                              Expanded(child: Text("Ishchilar oyligi bazaviy tarif emas, balki bajarilgan ish hajmi (Tariflar) orqali hisoblanadi.", style: TextStyle(fontSize: 12, color: Colors.orange))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // 3. Ruxsatlar (Huquqlar) qismi
                      Text("Ruxsatlar (Huquqlar):", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ..._availablePermissions.entries.map((entry) {
                        final key = entry.key;
                        final desc = entry.value;
                        final hasPerm = currentPermissions[key] == true;

                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(desc, style: const TextStyle(fontSize: 13)),
                          value: hasPerm,
                          activeColor: const Color(0xFF2E5BFF),
                          onChanged: (bool val) => setDialogState(() => currentPermissions[key] = val),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    try {
                      final data = {
                        'name': nameCtrl.text,
                        'role_type': roleType,
                        'permissions': currentPermissions,
                        'base_salary': isAupSelected ? (double.tryParse(baseSalaryCtrl.text) ?? 0) : 0,
                        'bonus_per_m2': isAupSelected ? (double.tryParse(bonusPerM2Ctrl.text) ?? 0) : 0,
                      };

                      if (isEditing) {
                        await _supabase.from('app_roles').update(data).eq('id', role['id']);
                      } else {
                        await _supabase.from('app_roles').insert(data);
                      }
                      
                      if (mounted) { Navigator.pop(context); _fetchRoles(); }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Saqlash"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // ─── ASOSIY EKRAN UI ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lavozimlar va Ruxsatlar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isAup = role['role_type'] == 'aup';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: isAup ? Colors.purple.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      child: Icon(isAup ? Icons.admin_panel_settings : Icons.engineering, color: isAup ? Colors.purple : Colors.orange),
                    ),
                    title: Text(role['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    // Subtitle endi aqlli bo'ldi! Lavozimning oyligini ko'rsatib turadi.
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isAup ? 'Boshqaruv (AUP)' : 'Ishchi xodim (Worker)'),
                        if (isAup) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Fiks: ${_formatMoney(role['base_salary'])} | Bonus: ${_formatMoney(role['bonus_per_m2'])}/m²", 
                            style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ]
                      ],
                    ),
                    trailing: const Icon(Icons.edit, color: Colors.grey),
                    onTap: () => _showRoleDialog(role: role),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E5BFF),
        onPressed: () => _showRoleDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yangi Lavozim", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
