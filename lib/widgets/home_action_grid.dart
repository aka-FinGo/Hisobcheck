import 'package:flutter/material.dart';
import '../screens/clients_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/manage_users_screen.dart';
import '../screens/manage_roles_screen.dart'; // YANGI SAHIFA IMPORT QILINDI
import '../screens/admin_panel_screen.dart';
class HomeActionGrid extends StatelessWidget {
  final bool isAdmin;
  final bool canManageUsers; // Shu ruxsat qo'shildi!
  final int totalOrders;
  final int activeOrders;
  final VoidCallback onWithdrawTap;

  const HomeActionGrid({
    super.key,
    required this.isAdmin,
    required this.canManageUsers,
    required this.totalOrders,
    required this.activeOrders,
    required this.onWithdrawTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          Row(
            children: [
              Expanded(child: _MiniStatTile(title: "Jami zakaz", value: "$totalOrders", icon: Icons.assignment_outlined, color: const Color(0xFF2E5BFF))),
              const SizedBox(width: 15),
              Expanded(child: _MiniStatTile(title: "Jarayonda", value: "$activeOrders", icon: Icons.hourglass_empty, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 20),
        ],

        Text("Tezkor amallar", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          childAspectRatio: 1.1,
          children: [
            _buildActionCard(context, title: "Mijozlar", icon: Icons.people_outline_rounded, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
            
            if (isAdmin) ...[
              _buildActionCard(context, title: "Hisobotlar", icon: Icons.insert_chart_outlined_rounded, color: const Color(0xFF6C3FE8), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
            ],
            
            // XODIMLAR VA LAVOZIMLAR O'RNIGA BITTA ADMIN PANEL TUGMASI:
            if (canManageUsers) ...[
              _buildActionCard(
                context, 
                title: "Admin Panel", 
                icon: Icons.admin_panel_settings_rounded, 
                color: Colors.redAccent, 
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()))
              ),
            ],
            
            if (!isAdmin) ...[
              _buildActionCard(context, title: "Avans so'rash", icon: Icons.money_rounded, color: Colors.green, onTap: onWithdrawTap),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.15), child: Icon(icon, size: 30, color: color)),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final String title; final String value; final IconData icon; final Color color;
  const _MiniStatTile({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
