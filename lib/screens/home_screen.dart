import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- MOLIYAVIY O'ZGARUVCHILAR ---
  double _companyCash = 0;    // Korxona kassasi (Orders - Withdrawals)
  double _workerDebt = 0;     // Ishchilarga berilishi kerak bo'lgan qoldiq
  double _myEarnings = 0;     // Shaxsiy ishlab topgan (WorkLogs)
  double _myAdvances = 0;     // Shaxsiy olingan (Withdrawals)
  
  int _totalOrders = 0;
  int _activeOrders = 0;
  int _pendingApprovals = 0;
  int _totalClientsCount = 0;

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

      // 1. KORXONA MOLIYASI
      final orders = await _supabase.from('orders').select('total_price, status');
      final allWith = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
      final allLogs = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);

      double rev = 0; for (var o in orders) rev += (o['total_price'] ?? 0).toDouble();
      double paid = 0; for (var w in allWith) paid += (w['amount'] ?? 0).toDouble();
      double earnedByAll = 0; for (var l in allLogs) earnedByAll += (l['total_sum'] ?? 0).toDouble();

      // 2. SHAXSIY MOLIYA
      final myL = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
      final myW = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
      
      double myE = 0; for (var ml in myL) myE += (ml['total_sum'] ?? 0).toDouble();
      double myA = 0; for (var mw in myW) myA += (mw['amount'] ?? 0).toDouble();

      // 3. STATISTIKA
      final pW = await _supabase.from('work_logs').select('id').eq('is_approved', false);
      final pA = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
      final cl = await _supabase.from('clients').select('id');

      setState(() {
        _companyCash = rev - paid; 
        _workerDebt = earnedByAll - paid;
        _myEarnings = myE; _myAdvances = myA;
        _totalOrders = orders.length;
        _activeOrders = orders.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        _pendingApprovals = pW.length + pA.length;
        _totalClientsCount = cl.length;
      });
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
  }
void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Avans so'rash"),
        content: TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('withdrawals').insert({'worker_id': _supabase.auth.currentUser!.id, 'amount': double.tryParse(amountCtrl.text) ?? 0, 'status': 'pending'});
              Navigator.pop(ctx);
              _loadAllData();
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
              HomeHeader(greeting: "Salom", userName: _userName),
              const SizedBox(height: 25),
              
              // BALANS CARD - Endi barcha moliya alohida!
              BalanceCard(
                role: _userRoleType, 
                companyBalance: _companyCash,
                totalWorkerDebt: _workerDebt,
                personalEarnings: _myEarnings,
                personalAdvances: _myAdvances,
                statsCount: _totalOrders,
              ),
              const SizedBox(height: 25),

              // MANA O'SHA YO'QOLGAN TUGMA!
              if (hasPermission('can_add_work_log'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 25),
                  child: SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E5BFF), 
                        foregroundColor: Colors.white, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.add_task, size: 28),
                      label: const Text("Bajargan ishni topshirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                    ),
                  ),
                ),

              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                totalOrders: _totalOrders, activeOrders: _activeOrders,
                pendingApprovalsCount: _pendingApprovals,
                totalClientsCount: _totalClientsCount, newClientsCount: 0,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: _showWithdrawDialog,
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadAllData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}