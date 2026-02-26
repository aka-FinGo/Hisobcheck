import 'package:flutter/material.dart';
import '../screens/clients_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/manage_users_screen.dart';
import '../screens/manage_roles_screen.dart'; 
import '../screens/admin_panel_screen.dart';
import '../screens/admin_approvals.dart'; // Tasdiqlashlar oynasi

class HomeActionGrid extends StatelessWidget {
  final bool isAdmin;
  final bool canManageUsers; 
  final int totalOrders;
  final int activeOrders;
  final int pendingApprovalsCount; // YANGILIK: Kutilayotgan ishlar/avanslar soni
  final VoidCallback onWithdrawTap;

  const HomeActionGrid({
    super.key,
    required this.isAdmin,
    required this.canManageUsers,
    required this.totalOrders,
    required this.activeOrders,
    this.pendingApprovalsCount = 0, // Default 0
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
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.3,
          children: [
            // RAHBAR TASDIG'I (Qizil bildirishnoma bilan)
            if (isAdmin) 
              _ActionCard(
                title: "Tasdiqlashlar", 
                icon: Icons.fact_check_outlined, 
                color: Colors.redAccent, 
                badgeCount: pendingApprovalsCount, // Raqamni shu yerga beramiz
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()))
              ),

            if (isAdmin) 
              _ActionCard(title: "Mijozlar", icon: Icons.people_alt, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
            
            if (isAdmin) 
              _ActionCard(title: "Statistika", icon: Icons.bar_chart, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
            
            if (canManageUsers) 
              _ActionCard(title: "Hodimlar", icon: Icons.manage_accounts, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
            
            if (canManageUsers) 
              _ActionCard(title: "Lavozimlar", icon: Icons.badge, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRolesScreen()))),
          ],
        ),
        
        const SizedBox(height: 25),

        // Hamma uchun umumiy bo'lgan AVANS SO'RASH tugmasi
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.money_off),
            label: const Text("Avans so'rash", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: onWithdrawTap,
          ),
        ),
      ],
    );
  }
}

// Yordamchi Widget: Ichida Badge chizish mantiqi bor
class _ActionCard extends StatelessWidget {
  final String title; 
  final IconData icon; 
  final Color color; 
  final VoidCallback onTap;
  final int badgeCount; // Qizil nuqtadagi raqam

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        clipBehavior: Clip.none, // Qizil nuqta chetdan chiqib turishi uchun
        children: [
          // Asosiy karta
          Container(
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, spreadRadius: 1)]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 28, backgroundColor: color.withOpacity(0.15), child: Icon(icon, size: 30, color: color)),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Qizil nuqta (Badge) faqat soni 0 dan ko'p bo'lsa chiqadi
          if (badgeCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
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
