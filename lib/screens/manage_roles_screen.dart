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

  final Map<String, String> _availablePermissions = {
    'can_view_finance': 'Kassa va Moliya bo\'limini ko\'rish',
    'can_add_order': 'Yangi zakaz qo\'shish',
    'can_manage_clients': 'Mijozlar bazasini boshqarish',
    'can_manage_users': 'Xodimlar va lavozimlarni boshqarish',
    'can_add_work_log': 'Bajargan ishini kiritish',
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

  void _showRoleDialog({Map<String, dynamic>? role}) {
    final isEditing = role != null;
    final nameCtrl = TextEditingController(text: isEditing ? role['name'] : '');
    final baseSalaryCtrl = TextEditingController(text: isEditing ? (role['base_salary'] ?? 0).toString() : '0');
    final ratePerUnitCtrl = TextEditingController(text: isEditing ? (role['rate_per_unit'] ?? 0).toString() : '0');
    
    String selectedUnit = isEditing ? (role['unit_type'] ?? 'dona') : 'dona';
    String roleType = isEditing ? role['role_type'] : 'worker';
    
    // YARATILGAN YANGILIK 1: Keyingi status o'zgaruvchisi
    String? targetStatus = isEditing ? role['target_status'] : null;

    Map<String, dynamic> currentPermissions = isEditing && role['permissions'] != null 
        ? Map<String, dynamic>.from(role['permissions']) : {};

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setST) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isEditing ? "Lavozimni tahrirlash" : "Yangi lavozim"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Lavozim nomi', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: roleType,
                        decoration: const InputDecoration(labelText: 'Toifasi', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'aup', child: Text('AUP (Boshqaruv)')),
                          DropdownMenuItem(value: 'worker', child: Text('Worker (Ishchi)')),
                        ],
                        onChanged: (val) => setST(() => roleType = val!),
                      ),
                      const Divider(height: 30),
                      
                      const Text("Moliya va To'lov shartlari", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: baseSalaryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fiks oylik maosh', suffixText: "so'm", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: selectedUnit,
                              decoration: const InputDecoration(labelText: 'Birlik', border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: 'dona', child: Text('dona')),
                                DropdownMenuItem(value: 'metr', child: Text('metr')),
                                DropdownMenuItem(value: 'm2', child: Text('m²')),
                                DropdownMenuItem(value: 'kg', child: Text('kg')),
                              ],
                              onChanged: (val) => setST(() => selectedUnit = val!),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ratePerUnitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Stavka', suffixText: "so'm", border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // YARATILGAN YANGILIK 1 (UI): Avtomatizatsiya
                      const Text("Avtomatizatsiya (Pipeline)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: targetStatus,
                        decoration: const InputDecoration(
                          labelText: "Ish topshirilgach zakaz qayerga o'tadi?",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text("Status o'zgarmaydi")),
                          DropdownMenuItem(value: 'material', child: Text("Kesish/Material ->")),
                          DropdownMenuItem(value: 'assembly', child: Text("Yig'ish ->")),
                          DropdownMenuItem(value: 'delivery', child: Text("O'rnatish ->")),
                          DropdownMenuItem(value: 'completed', child: Text("Yakunlandi (Tugadi)")),
                        ],
                        onChanged: (val) => setST(() => targetStatus = val),
                      ),
                      const Divider(height: 20),
                      
                      const Text("Ruxsatlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                      ..._availablePermissions.entries.map((entry) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value, style: const TextStyle(fontSize: 12)),
                        value: currentPermissions[entry.key] == true,
                        onChanged: (val) => setST(() => currentPermissions[entry.key] = val),
                      )),
                    ],
                  ),
                ),
              ),
              actions: [
                // YARATILGAN YANGILIK 2: O'CHIRISH TUGMASI (Faqat tahrirlashda)
                if (isEditing)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text("Diqqat!"),
                          content: const Text("Ushbu lavozimni haqiqatan ham o'chirmoqchimisiz?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Yo'q")),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () => Navigator.pop(c, true), 
                              child: const Text("Ha, o'chirish")
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await _supabase.from('app_roles').delete().eq('id', role['id']);
                          if (mounted) {
                            Navigator.pop(context);
                            _fetchRoles();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Xatolik: Ushbu lavozimga xodimlar biriktirilgan!"), backgroundColor: Colors.red)
                            );
                          }
                        }
                      }
                    },
                    child: const Text("O'chirish", style: TextStyle(color: Colors.red)),
                  ),
                  
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish")),
                ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    try {
                      final data = {
                        'name': nameCtrl.text,
                        'role_type': roleType,
                        'permissions': currentPermissions,
                        'base_salary': double.tryParse(baseSalaryCtrl.text) ?? 0,
                        'rate_per_unit': double.tryParse(ratePerUnitCtrl.text) ?? 0,
                        'unit_type': selectedUnit,
                        'target_status': targetStatus, // Avtomatizatsiyani bazaga yozamiz
                      };

                      if (isEditing) {
                        await _supabase.from('app_roles').update(data).eq('id', role['id']);
                      } else {
                        await _supabase.from('app_roles').insert(data);
                      }
                      
                      if (mounted) { 
                        Navigator.pop(context);
                        _fetchRoles(); 
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lavozimlar va Ruxsatlar')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _roles.length,
              itemBuilder: (context, index) {
                final role = _roles[index];
                final isAup = role['role_type'] == 'aup';
                
                // Ro'yxatda target_status ni chiroyli ko'rsatish uchun
                String targetDisplay = "Status o'zgarmaydi";
                if (role['target_status'] == 'material') targetDisplay = "-> Kesish";
                if (role['target_status'] == 'assembly') targetDisplay = "-> Yig'ish";
                if (role['target_status'] == 'delivery') targetDisplay = "-> O'rnatish";
                if (role['target_status'] == 'completed') targetDisplay = "-> Yakunlandi";

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAup ? Colors.purple.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      child: Icon(isAup ? Icons.admin_panel_settings : Icons.engineering, color: isAup ? Colors.purple : Colors.orange),
                    ),
                    title: Text(role['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Stavka: ${_formatMoney(role['rate_per_unit'])} / ${role['unit_type'] ?? 'dona'}"),
                        Text(targetDisplay, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                      ],
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showRoleDialog(role: role),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleDialog(),
        icon: const Icon(Icons.add),
        label: const Text("Yangi Lavozim"),
      ),
    );
  }
}
