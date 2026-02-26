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
    
    // Yangi qo'shilgan birlik tanlash qismi
    String selectedUnit = isEditing ? (role['unit_type'] ?? 'dona') : 'dona';
    String roleType = isEditing ? role['role_type'] : 'worker';
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
                      
                      // MOLIYA QISMI - ENDI HAMMA UCHUN OCHIQLADIK
                      const Text("Moliya va To'lov shartlari", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: baseSalaryCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fiks oylik maosh', suffixText: "so'm", border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      
                      // Birlik tanlash va Summa (Unit selection)
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
                      const Divider(height: 30),
                      
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
                        Text("Fiks: ${_formatMoney(role['base_salary'])}"),
                        Text("Stavka: ${_formatMoney(role['rate_per_unit'])} / ${role['unit_type'] ?? 'dona'}"),
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
