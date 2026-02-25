import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui'; 

import 'manage_users_screen.dart';
import 'clients_screen.dart';
import 'stats_screen.dart';
import 'user_profile_screen.dart';
import '../theme/theme_provider.dart';

// ─── CONSTANTLAR ────────────────────────────────────────────
class AppRoles {
  static const admin = 'admin';
  static const worker = 'worker';
  static const installer = 'installer';
}

class OrderStatus {
  static const pending = 'pending';
  static const completed = 'completed';
  static const canceled = 'canceled';
}
// ────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  String _userRole = AppRoles.worker;
  String _userName = '';

  double _displayEarned = 0;
  double _displayWithdrawn = 0;

  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ─── MA'LUMOT YUKLASH ──────────────────────────────────────
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
          
      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      
      if (_userRole == AppRoles.admin) {
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase
            .from('withdrawals')
            .select('amount')
            .eq('status', 'approved');
            
        double totalIncome = 0;
        double totalPaid = 0;
        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;
            _displayWithdrawn = totalPaid;
            _totalOrders = orders.length;
            _activeOrders = orders
                .where((o) =>
                    o['status'] != OrderStatus.completed &&
                    o['status'] != OrderStatus.canceled)
                .length;
            _isLoading = false;
          });
        }
      } else {
        final works = await _supabase
            .from('work_logs')
            .select('total_sum')
            .eq('worker_id', user.id)
            .eq('is_approved', true);
        final withdraws = await _supabase
            .from('withdrawals')
            .select('amount')
            .eq('worker_id', user.id)
            .eq('status', 'approved');
            
        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── FORMATLAR ─────────────────────────────────────────────
  String _formatMoney(double amount) => "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
      
  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  // ─── DIALOGS (AVANS SO'RASH) ─────────────────────────────────
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final double balance = _displayEarned - _displayWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // RANGNI MAVZUDAN OLADI
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Text("Avans so'rash", style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wallet, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Text("Mavjud balans: ", style: Theme.of(context).textTheme.bodyMedium),
                  Text(_formatMoney(balance),
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                labelText: "Summa",
                suffixText: "so'm",
                labelStyle: Theme.of(context).textTheme.bodyMedium,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E5BFF), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Bekor", style: Theme.of(context).textTheme.bodyMedium),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E5BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount <= 0 || amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Noto'g'ri summa yoki balans yetarli emas!"), backgroundColor: Colors.red));
                return;
              }
              try {
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id,
                  'amount': amount,
                  'status': OrderStatus.pending,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov yuborildi!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Yuborish"),
          ),
        ],
      ),
    ).whenComplete(() => amountCtrl.dispose());
  }

  // ─── UI YASASH QISMI ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Ekranni tepasiga kerak bo'lsa padding qo'shib olamiz
    return Scaffold(
      // Orqa fonni bermaymiz! Tizim o'zi oq, qora yoki shaffof qilib chizadi.
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 25),
                    
                    // Admin uchun
                    if (_userRole == AppRoles.admin) _buildAdminMiniStats(),
                    if (_userRole == AppRoles.admin) const SizedBox(height: 20),
                    
                    // Katta balans karta
                    _buildBalanceCard(),
                    const SizedBox(height: 30),
                    
                    Text("Tezkor amallar", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    
                    // Menyular 
                    _buildMenuGrid(),
                  ],
                ),
              ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_greeting, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(_userName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
          child: CircleAvatar(
            radius: 25,
            backgroundColor: const Color(0xFF2E5BFF).withOpacity(0.15),
            child: Text(
              _userName.isNotEmpty ? _userName[0].toUpperCase() : "A",
              style: const TextStyle(color: Color(0xFF2E5BFF), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ─── ADMIN MINI STATS ──────────────────────────────────────
  Widget _buildAdminMiniStats() {
    return Row(
      children: [
        Expanded(
          child: _MiniStatTile(
            title: "Jami zakaz",
            value: "$_totalOrders",
            icon: Icons.assignment_outlined,
            color: const Color(0xFF2E5BFF),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _MiniStatTile(
            title: "Jarayonda",
            value: "$_activeOrders",
            icon: Icons.hourglass_empty,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  // ─── BALANCE KARTA ───────────────────────────────────────────
  Widget _buildBalanceCard() {
    final isAdmin = _userRole == AppRoles.admin;
    final double balance = _displayEarned - _displayWithdrawn;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      // Agar Glass bo'lsa CardTheme o'zi rangini beradi. Lekin ustiga chiroyli ko'k Gradient tortish mumkin.
      // Biz hozircha oddiy Card'da qoldiramiz.
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF2E5BFF), Color(0xFF6C3FE8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2E5BFF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isAdmin ? "Jami aylanma (Daromad)" : "Ishlangan mablag'", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ],
            ),
            const SizedBox(height: 10),
            Text(_formatMoney(_displayEarned), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BalanceRow(
                    label: isAdmin ? "Xarajatlar" : "Olingan",
                    value: _formatMoney(_displayWithdrawn),
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.redAccent.shade100,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _BalanceRow(
                      label: isAdmin ? "Sof Foyda" : "Qoldiq",
                      value: _formatMoney(balance),
                      icon: Icons.savings_outlined,
                      color: Colors.greenAccent.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── MENYU GRID ─────────────────────────────────────────────
  Widget _buildMenuGrid() {
    final items = <_MenuItem>[
      _MenuItem(
        title: "Mijozlar",
        icon: Icons.people_outline_rounded,
        color: Colors.orange,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
      ),
      if (_userRole == AppRoles.admin) ...[
        _MenuItem(
          title: "Hisobotlar",
          icon: Icons.insert_chart_outlined_rounded,
          color: const Color(0xFF6C3FE8),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
        ),
        _MenuItem(
          title: "Xodimlar",
          icon: Icons.manage_accounts_outlined,
          color: Colors.teal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
        ),
      ] else ...[
        _MenuItem(
          title: "Avans so'rash",
          icon: Icons.money_rounded,
          color: Colors.green,
          onTap: _showWithdrawDialog, // Admin bo'lmasa avans so'rashni ochadi
        ),
      ],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(15),
          child: Card(
            margin: EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: item.color.withOpacity(0.15),
                  child: Icon(item.icon, size: 30, color: item.color),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── YORDAMCHI WIDGET'LAR ─────────────────────────────────────
class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _MiniStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStatTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
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

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
