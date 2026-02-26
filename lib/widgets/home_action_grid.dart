import 'package:flutter/material.dart';
import '../screens/clients_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/manage_users_screen.dart';
import '../screens/manage_roles_screen.dart'; 
import '../screens/admin_approvals.dart';
import '../screens/orders_list_screen.dart'; // Zakazlar ro'yxati uchun

class HomeActionGrid extends StatelessWidget {
  final bool isAdmin;
  final bool canManageUsers; 
  final int totalOrders;
  final int activeOrders;
  final int pendingApprovalsCount;
  final int totalClientsCount;     // Jami mijozlar
  final int newClientsCount;       // Yangi (+1) mijozlar
  final bool showWithdrawOption;
  final VoidCallback onWithdrawTap;
  final VoidCallback onClientsTap; // Mijozlarga o'tganda badgeni o'chirish uchun

  const HomeActionGrid({
    super.key,
    required this.isAdmin,
    required this.canManageUsers,
    required this.totalOrders,
    required this.activeOrders,
    this.pendingApprovalsCount = 0,
    this.totalClientsCount = 0,
    this.newClientsCount = 0,
    required this.showWithdrawOption,
    required this.onWithdrawTap,
    required this.onClientsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdmin) ...[
          Row(
            children: [
              Expanded(
                child: _MiniStatTile(
                  title: "Jami zakaz", 
                  value: "$totalOrders", 
                  icon: Icons.assignment_outlined, 
                  color: theme.colorScheme.primary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen(filter: 'all'))),
                )
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _MiniStatTile(
                  title: "Jarayonda", 
                  value: "$activeOrders", 
                  icon: Icons.hourglass_empty, 
                  color: Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersListScreen(filter: 'active'))),
                )
              ),
            ],
          ),
          const SizedBox(height: 25),
        ],

        Text("Tezkor amallar", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 15,
          crossAxisSpacing: 15,
          childAspectRatio: 1.3,
          children: [
            if (isAdmin) 
              _ActionCard(
                title: "Tasdiqlashlar", 
                icon: Icons.fact_check_outlined, 
                color: Colors.redAccent, 
                badgeValue: pendingApprovalsCount > 0 ? pendingApprovalsCount.toString() : null,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()))
              ),

            if (isAdmin) 
              _ActionCard(
                title: "Mijozlar", 
                icon: Icons.people_alt, 
                color: Colors.blue, 
                subTitle: "$totalClientsCount ta",
                badgeValue: newClientsCount > 0 ? "+$newClientsCount" : null, // Yangi mijozlar badge'i
                onTap: onClientsTap,
              ),
            
            if (isAdmin) 
              _ActionCard(title: "Statistika", icon: Icons.bar_chart, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
            
            if (canManageUsers) 
              _ActionCard(title: "Hodimlar", icon: Icons.manage_accounts, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
            
            if (canManageUsers) 
              _ActionCard(title: "Lavozimlar", icon: Icons.badge, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRolesScreen()))),
          ],
        ),
        
        if (showWithdrawOption) ...[
           const SizedBox(height: 25),
           _WithdrawButton(onTap: onWithdrawTap),
        ]
      ],
    );
  }
}
// ─── ACTION CARD (THEME ADAPTIVE) ───────────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badgeValue;

  const _ActionCard({
    required this.title, 
    this.subTitle, 
    required this.icon, 
    required this.color, 
    required this.onTap, 
    this.badgeValue
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.cardColor, // Mavzuga qarab o'zgaradi
              borderRadius: BorderRadius.circular(15),
              border: isDark ? Border.all(color: Colors.white10) : null,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4)
                )
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26, 
                  backgroundColor: color.withOpacity(isDark ? 0.2 : 0.1), 
                  child: Icon(icon, size: 28, color: color)
                ),
                const SizedBox(height: 10),
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (subTitle != null)
                  Text(subTitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
              ],
            ),
          ),
          
          if (badgeValue != null)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.scaffoldBackgroundColor, width: 2),
                ),
                child: Text(
                  badgeValue!,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── MINI STAT TILE (THEME ADAPTIVE) ─────────────────────────────
class _MiniStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniStatTile({required this.title, required this.value, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isDark ? Border.all(color: Colors.white10) : null,
          boxShadow: [BoxShadow(color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.05), blurRadius: 4)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10), maxLines: 1),
                  Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WITHDRAW BUTTON ──────────────────────────────────────────
class _WithdrawButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WithdrawButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange,
          side: const BorderSide(color: Colors.orange, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.money_off),
        label: const Text("Avans so'rash", style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
    );
  }
}