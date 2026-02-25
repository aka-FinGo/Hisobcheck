import 'package:flutter/material.dart';
import 'manage_users_screen.dart';
import 'manage_roles_screen.dart';
// Kelajakda Tariflar (TaskTypes) uchun ham import qo'shiladi
// import 'task_types_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boshqaruv Paneli (Admin)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "Tizim Sozlamalari",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          // 1. Xodimlarni boshqarish
          _buildAdminMenuCard(
            context,
            title: "Xodimlar ro'yxati",
            subtitle: "Yangi ishchi qo'shish, ishdan bo'shatish va ma'lumotlarini tahrirlash",
            icon: Icons.manage_accounts_rounded,
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
          
          const SizedBox(height: 12),

          // 2. Lavozimlar va Ruxsatlar
          _buildAdminMenuCard(
            context,
            title: "Lavozimlar va Ruxsatlar",
            subtitle: "Lavozim yaratish, maosh va ruxsatlarni (RBAC) belgilash",
            icon: Icons.admin_panel_settings_rounded,
            color: Colors.redAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRolesScreen())),
          ),

          const SizedBox(height: 12),

          // 3. Kelajakdagi Tariflar uchun tayyorlab ketamiz
          _buildAdminMenuCard(
            context,
            title: "Ishbay Tariflar (Narxlar)",
            subtitle: "Ishchilar uchun qilinadigan ish turlari va narxlarini belgilash",
            icon: Icons.price_change_rounded,
            color: Colors.orange,
            onTap: () {
              // Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskTypesScreen()));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tez orada qo'shiladi!")));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenuCard(BuildContext context, {
    required String title, 
    required String subtitle, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
