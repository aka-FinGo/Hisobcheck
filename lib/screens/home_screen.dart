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

  // Profil ma'lumotlari
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- MOLIYAVIY O'ZGARUVCHILAR (Missing variables fixed) ---
  double _totalCompanyCash = 0; // Jami tushum - Jami chiqim
  double _unpaidEarnings = 0;   // Ishchilarga berilishi kerak bo'lgan qarz
  double _myEarnings = 0;       // Shaxsiy ishlab topgan maosh
  double _myAdvances = 0;       // Shaxsiy olingan avanslar
  
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

  // BU YERDA DAVOMI (2-QISMDA) KELADI...
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

      // 1. KORXONA DAROMADI (Orders jadvalidan)
      final orders = await _supabase.from('orders').select('total_price, status');
      double totalRevenue = 0;
      for (var o in orders) totalRevenue += (o['total_price'] ?? 0).toDouble();

      // 2. JAMI TO'LANGAN AVANSLAR (Withdrawals approved)
      final allApprovedWithdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
      double totalPaidOut = 0;
      for (var w in allApprovedWithdrawals) totalPaidOut += (w['amount'] ?? 0).toDouble();

      // 3. JAMI ISHLAB TOPILGAN ISH HAQI (Work Logs approved)
      final allApprovedLogs = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
      double totalWorkDebt = 0;
      for (var l in allApprovedLogs) totalWorkDebt += (l['total_sum'] ?? 0).toDouble();

      // 4. SHAXSIY HISOB-KITOB (Faqat joriy foydalanuvchi uchun)
      final myLogs = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
      final myWithdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
      
      double myEarned = 0;
      for (var ml in myLogs) myEarned += (ml['total_sum'] ?? 0).toDouble();
      double myPaid = 0;
      for (var mw in myWithdraws) myPaid += (mw['amount'] ?? 0).toDouble();

      // Qolgan statistikalar
      final pWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
      final pAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
      final clients = await _supabase.from('clients').select('id');

      setState(() {
        _totalCompanyCash = totalRevenue - totalPaidOut; // Kassadagi sof pul
        _unpaidEarnings = totalWorkDebt - totalPaidOut;  // Ishchilarga berilishi kerak bo'lgan qoldiq qarz
        _myEarnings = myEarned;
        _myAdvances = myPaid;
        _totalOrders = orders.length;
        _activeOrders = orders.where((o) => ['pending','material','assembly','delivery'].contains(o['status'])).length;
        _pendingApprovals = pWorks.length + pAvans.length;
        _totalClientsCount = clients.length;
      });
    } catch (e) { debugPrint("Xato: $e"); }
    finally { if (mounted) setState(() => _isLoading = false); }
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
              HomeHeader(greeting: "Xush kelibsiz", userName: _userName),
              const SizedBox(height: 25),
              BalanceCard(
                role: _userRoleType, 
                companyBalance: _totalCompanyCash,
                totalWorkerDebt: _unpaidEarnings,
                personalEarnings: _myEarnings,
                personalAdvances: _myAdvances,
                statsCount: _totalOrders,
              ),
              const SizedBox(height: 25),
              HomeActionGrid(
                isAdmin: _isSuperAdmin || _userRoleType == 'aup',
                canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                totalOrders: _totalOrders, activeOrders: _activeOrders,
                pendingApprovalsCount: _pendingApprovals,
                totalClientsCount: _totalClientsCount, newClientsCount: _newClientsCount,
                showWithdrawOption: _userRoleType == 'worker',
                onWithdrawTap: () {}, // Avvalgi mantiq qoladi
                onClientsTap: () => Navigator.pushNamed(context, '/clients').then((_) => _loadAllData()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}