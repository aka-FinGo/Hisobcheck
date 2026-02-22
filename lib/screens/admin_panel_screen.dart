import 'package:flutter/material.dart';

// Admin sahifalari importi
import 'manage_users_screen.dart';
import 'admin_task_types_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Admin Panel", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2, 
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        children: [
          _buildAdminCard(
            context,
            title: "Xodimlar\nva Rollar",
            icon: Icons.manage_accounts_rounded,
            color: Colors.redAccent,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
          ),
          
          _buildAdminCard(
            context,
            title: "Lavozim va\nTa'riflar",
            icon: Icons.request_quote_rounded,
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminTaskTypesScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 35, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF2D3142)),
            ),
          ],
        ),
      ),
    );
  }
}
