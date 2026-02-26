import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// O'zimiz yozgan widjetlarni chaqiramiz
import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart'; 
import 'orders_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // --- Ruxsatlar va Profil ---
  bool _isSuperAdmin = false;
  String _userName = '';
  String _userRoleType = 'worker'; 
  String _positionName = 'Hodim';  
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  // --- Kassa va Statistika o'zgaruvchilari ---
  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  double _secondaryBalance = 0; 
  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  
  // --- Bildirishnomalar (Badge) soni ---
  int _pendingApprovals = 0; // Tasdiqlashlar uchun
  int _totalClientsCount = 0; // Jami mijozlar
  int _newClientsCount = 0;   // Yangi mijozlar (+1)

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Ruxsatlarni tekshirish mantiqi
  bool hasPermission(String action) {
    if (_isSuperAdmin) return true; 
    if (_customPermissions.containsKey(action)) return _customPermissions[action] == true;
    if (_rolePermissions.containsKey(action)) return _rolePermissions[action] == true;
    return false; 
  }

  // MA'LUMOTLARNI YUKLASH (SUPABASE)
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type, permissions)')
          .eq('id', user.id)
          .single();

      _userName = profile['full_name'] ?? 'Foydalanuvchi';
      _isSuperAdmin = profile['is_super_admin'] ?? false;
      _customPermissions = profile['custom_permissions'] ?? {};
      
      if (profile['app_roles'] != null) {
        _positionName = profile['app_roles']['name'] ?? 'Hodim';
        _userRoleType = profile['app_roles']['role_type'] ?? 'worker';
        _rolePermissions = profile['app_roles']['permissions'] ?? {};
      }

      // ADMIN VA AUP UCHUN MA'LUMOTLAR
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // 1. Zakazlar statistikasi
        final orders = await _supabase.from('orders').select('total_price, status');
        // 2. Kutilayotgan tasdiqlar (Ishlar + Avanslar)
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        // 3. Mijozlar (+1 mantiqi bilan)
        final clientsRes = await _supabase.from('clients').select('id, created_at');

        double totalInc = 0; int active = 0;
        for (var o in orders) {
          totalInc += (o['total_price'] ?? 0).toDouble();
          if (['pending', 'material', 'assembly', 'delivery'].contains(o['status'])) active++;
        }

        // Oxirgi 24 soat ichida qo'shilgan mijozlarni aniqlash
        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        final recentOnes = clientsRes.where((c) => DateTime.parse(c['created_at']).isAfter(dayAgo)).length;

        if (mounted) {
          setState(() {
            _displayEarned = totalInc;
            _totalOrders = orders.length;
            _activeOrders = active;
            _pendingApprovals = pendingWorks.length + pendingAvans.length; // Haqiqiy son ulandi!
            _totalClientsCount = clientsRes.length;
            _newClientsCount = recentOnes; // +1 mantiqi
          });
        }
      } else {
        // ODDIY ISHCHI UCHUN MA'LUMOTLAR
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
        double earned = 0; double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _secondaryBalance = earned - paid;
            _pendingApprovals = 0;
          });
        }
      }
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
// AVANS SO'RASH DIALOGI
  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Avans so'rash"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa")),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Sababi (ixtiyoriy)")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                setDialogState(() => isSubmitting = true);
                try {
                  await _supabase.from('withdrawals').insert({
                    'worker_id': _supabase.auth.currentUser!.id,
                    'amount': double.tryParse(amountCtrl.text) ?? 0,
                    'description': descCtrl.text,
                    'status': 'pending'
                  });
                  Navigator.pop(ctx);
                  _loadAllData();
                } finally {
                  setDialogState(() => isSubmitting = false);
                }
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
              // 1. SALOMLASHISH
              HomeHeader(greeting: "Xush kelibsiz", userName: _userName),
              const SizedBox(height: 25),
              
              // 2. KASSA KARTASI
              BalanceCard(
                role: (_isSuperAdmin || hasPermission('can_view_finance')) ? 'admin' : 'worker',
                mainBalance: _displayEarned - _displayWithdrawn,
                income: _displayEarned, expense: _displayWithdrawn,
                secondaryBalance: _secondaryBalance, statsCount: _statsCount,
              ),
              const SizedBox(height: 25),

              // 3. ISH TOPSHIRISH TUGMASI
              if (hasPermission('can_add_work_log')) ...[
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5BFF), 
                      foregroundColor: Colors.white, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                    ),
                    icon: const Icon(Icons.add_task), label: const Text("Ishni topshirish", style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWorkLogScreen())).then((_) => _loadAllData()),
                  ),
                ),
                const SizedBox(height: 25),
              ],

              // 4. TEZKOR TUGMALAR GRIDI
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
                onClientsTap: () {
                  // Mijozlar sahifasiga o'tish va badge'ni o'chirish
                  setState(() => _newClientsCount = 0);
                  Navigator.pushNamed(context, '/clients').then((_) => _loadAllData());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}