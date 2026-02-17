import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_task_types_screen.dart';
import 'manage_users_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _supabase = Supabase.instance.client;
  String _companyName = "Yuklanmoqda...";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _supabase.from('app_settings').select().eq('key', 'company_name').maybeSingle();
      if (mounted) setState(() => _companyName = data?['value'] ?? 'Aristokrat Mebel');
    } catch (e) {
      if (mounted) setState(() => _companyName = 'Aristokrat Mebel');
    }
  }

  Future<void> _updateCompanyName() async {
    final controller = TextEditingController(text: _companyName);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Kompaniya nomi"),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: "Nomni kiriting")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('app_settings').upsert({'key': 'company_name', 'value': controller.text});
              if (mounted) {
                setState(() => _companyName = controller.text);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nom saqlandi!")));
              }
            },
            child: const Text("SAQLASH"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. KOMPANIYA NOMI
          _buildSectionHeader("Umumiy Sozlamalar"),
          Card(
            child: ListTile(
              leading: const Icon(Icons.business, color: Colors.indigo),
              title: const Text("Kompaniya nomi"),
              subtitle: Text(_companyName),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: _updateCompanyName,
            ),
          ),
          
          const SizedBox(height: 20),

          // 2. ISH TURLARI VA NARXLAR
          _buildSectionHeader("Moliyaviy Sozlamalar"),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.list_alt, color: Colors.green),
                  title: const Text("Ish turlari va Narxlar"),
                  subtitle: const Text("Yangi ish qo'shish, narxlarni o'zgartirish"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaskTypesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.people_alt, color: Colors.orange),
                  title: const Text("Xodimlar va Rollar"),
                  subtitle: const Text("Yangi xodim qo'shish, rollarni boshqarish"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. TIZIM
          _buildSectionHeader("Tizim Ma'lumotlari"),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, color: Colors.grey),
              title: Text("Dastur versiyasi"),
              subtitle: Text("v1.0.0 (Beta)"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}