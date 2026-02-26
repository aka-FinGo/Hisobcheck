import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Profil va Ruxsatlar
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // Kassa va Statistika
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0; 
  int _totalOrders = 0;
  int _activeOrders = 0;
  
  // Bildirishnomalar (Badges)
  int _pendingApprovals = 0;
  int _totalClientsCount = 0;
  int _newClientsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  bool hasPermission(String action) {
    if (_isSuperAdmin) return true; 
    if (_customPermissions.containsKey(action)) return _customPermissions[action] == true;
    if (_rolePermissions.containsKey(action)) return _rolePermissions[action] == true;
    return false; 
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select('*, app_roles(*)').eq('id', user.id).single();

      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      
      if (profile['app_roles'] != null) {
        _userRoleType = profile['app_roles']['role_type'] ?? 'worker';
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      // MA'LUMOTLARNI HISOB-KITOB QILISH (Admin/Worker uchun alohida)
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        final orders = await _supabase.from('orders').select('total_price, status');
        final clients = await _supabase.from('clients').select('id, created_at');
        final pendingW = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingA = await _supabase.from('withdrawals').select('id').eq('status', 'pending');

        int active = orders.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        int recent = clients.where((c) => DateTime.parse(c['created_at']).isAfter(dayAgo)).length;

        setState(() {
          _totalOrders = orders.length;
          _activeOrders = active;
          _pendingApprovals = pendingW.length + pendingA.length;
          _totalClientsCount = clients.length;
          _newClientsCount = recent;
        });
      }
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
// AVANS SO'RASH FUNKSIYASI (Logic shu yerda qoladi)
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Avans so'rash"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa")),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Izoh")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setDialogState(() => isSubmitting = true);
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id,
                  'amount': double.tryParse(amountCtrl.text) ?? 0,
                  'description': descCtrl.text,
                  'status': 'pending'
                });
                Navigator.pop(ctx);
                _loadAllData(); // MUHIM: Bazaga yozgach raqamlarni yangilash
              },
              child: const Text("Yuborish"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
          onRefresh: _loadAllData,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              HomeHeader(greeting: "Salom", userName: _userName),
              const SizedBox(height: 25),
              BalanceCard(
                role: (_isSuperAdmin || hasPermission('can_view_finance')) ? 'admin' : 'worker',
                mainBalance: _displayEarned - _displayWithdrawn,
                income: _displayEarned, expense: _displayWithdrawn,
                secondaryBalance: _secondaryBalance, statsCount: 0,
              ),
              const SizedBox(height: 25),
              // TEZKOR TUGMALAR (Tugma u yerda, lekin pult shu yerda)
              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                totalOrders: _totalOrders, activeOrders: _activeOrders,
                pendingApprovalsCount: _pendingApprovals,
                totalClientsCount: _totalClientsCount,
                newClientsCount: _newClientsCount,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: _showWithdrawDialog, // MIYADAGI FUNKSIYANI BERDIK
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadAllData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}