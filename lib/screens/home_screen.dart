import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart'; 
import 'clients_screen.dart'; // MUHIM: Mijozlar sahifasi importi

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  double _displayEarned = 0; // Jami ishlangan pul (Ishchi) yoki Daromad (Admin)
  double _displayWithdrawn = 0; // Olingan pullar (Avans)
  double _secondaryBalance = 0; // Qoldiq
  int _totalOrders = 0;
  int _activeOrders = 0;
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

      // 1. Profil va Role'ni position_id orqali olish (Schema bo'yicha)
      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles!profiles_position_id_fkey(name, role_type, permissions)')
          .eq('id', user.id)
          .single();

      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      _customPermissions = profile['custom_permissions'] ?? {};
      
      if (profile['app_roles'] != null) {
        _userRoleType = profile['app_roles']['role_type'] ?? 'worker';
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // --- ADMIN BALANSI (KORXONA) ---
        final ordersRes = await _supabase.from('orders').select('total_price, status');
        final approvedWithdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
        final clientsRes = await _supabase.from('clients').select('id, created_at');
        final pWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');

        double totalIncome = 0;
        for (var o in ordersRes) totalIncome += (o['total_price'] ?? 0).toDouble();
        
        double totalExpenses = 0;
        for (var w in approvedWithdrawals) totalExpenses += (w['amount'] ?? 0).toDouble();

        setState(() {
          _displayEarned = totalIncome;
          _displayWithdrawn = totalExpenses;
          _secondaryBalance = totalIncome - totalExpenses;
          _totalOrders = ordersRes.length;
          _activeOrders = ordersRes.where((o) => o['status'] != 'completed' && o['status'] != 'canceled').length;
          _pendingApprovals = pWorks.length + pAvans.length;
          _totalClientsCount = clientsRes.length;
        });
      } else {
        // --- HODIM BALANSI ---
        // 1. Tasdiqlangan ishlari
        final approvedWorks = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        // 2. Olingan avanslari (approved holatdagisi)
        final myWithdrawals = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');

        double earned = 0;
        for (var l in approvedWorks) earned += (l['total_sum'] ?? 0).toDouble();
        
        double withdrawn = 0;
        for (var w in myWithdrawals) withdrawn += (w['amount'] ?? 0).toDouble();

        setState(() {
          _displayEarned = earned;
          _displayWithdrawn = withdrawn;
          _secondaryBalance = earned - withdrawn;
        });
      }
    } catch (e) {
      debugPrint("Balans yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Avans so'rash"),
        content: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('withdrawals').insert({
                'worker_id': _supabase.auth.currentUser!.id, 
                'amount': double.tryParse(amountCtrl.text) ?? 0, 
                'status': 'pending'
              });
              Navigator.pop(ctx);
              _loadAllData(); // Balansni yangilash
            },
            child: const Text("Yuborish"),
          ),
        ],
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
              HomeHeader(greeting: "Assalomu alaykum", userName: _userName),
              const SizedBox(height: 25),
              
              // BALANS CARD (Ma'lumotlar endi bazadan aniq hisoblandi)
              BalanceCard(
                role: (_isSuperAdmin || hasPermission('can_view_finance')) ? 'admin' : 'worker',
                mainBalance: _secondaryBalance, // Hamyondagi sof pul
                income: _displayEarned, // Jami daromad/ish haqi
                expense: _displayWithdrawn, // Chiqim/Avans
                secondaryBalance: _secondaryBalance,
                statsCount: _totalOrders,
              ),
              const SizedBox(height: 25),

              if (hasPermission('can_add_work_log'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      icon: const Icon(Icons.add_task), label: const Text("Ish topshirish"),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                    ),
                  ),
                ),

              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                totalOrders: _totalOrders,
                activeOrders: _activeOrders,
                pendingApprovalsCount: _pendingApprovals,
                totalClientsCount: _totalClientsCount,
                newClientsCount: _newClientsCount,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: _showWithdrawDialog,
                // MIJOZLAR TUGMASI ENDI ISHLAYDI:
                onClientsTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())).then((_) => _loadAllData());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}