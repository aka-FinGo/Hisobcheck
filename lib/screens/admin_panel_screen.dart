import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_task_types_screen.dart'; // Tariflar sahifasi
import 'manage_users_screen.dart';     // Xodimlar sahifasi

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

  // Kompaniya nomini o'zgartirish
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
          // 1. HEADER (Kompaniya Nomi)
          _buildSectionHeader("ASOSIY"),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.business, color: Colors.indigo),
              ),
              title: const Text("Kompaniya nomi", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_companyName),
              trailing: IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: _updateCompanyName,
              ),
            ),
          ),
          
          const SizedBox(height: 25),

          // 2. MOLIYAVIY SOZLAMALAR (Tariflar va Rollar)
          _buildSectionHeader("ISH VA TARIFLAR"),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                _buildMenuTile(
                  title: "Ish turlari va Narxlar",
                  subtitle: "Standart narxlarni belgilash",
                  icon: Icons.monetization_on,
                  color: Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaskTypesScreen())),
                ),
                const Divider(height: 1, indent: 60),
                _buildMenuTile(
                  title: "Xodimlar va Rollar",
                  subtitle: "Yangi xodim qo'shish, lavozim o'zgartirish",
                  icon: Icons.people_alt,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // 3. QO'SHIMCHA
          _buildSectionHeader("TIZIM"),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.security, color: Colors.grey),
                  title: const Text("Xavfsizlik sozlamalari"),
                  subtitle: const Text("Login va parollarni tiklash"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Kelajakda global xavfsizlik sahifasi
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tez kunda...")));
                  },
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: Colors.grey),
                  title: Text("Dastur versiyasi"),
                  subtitle: Text("v1.0.2 (Beta)"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 10),
      child: Text(title, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
    );
  }

  Widget _buildMenuTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}