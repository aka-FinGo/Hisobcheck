import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/home_header.dart';
import '../widgets/balance_card.dart';
import '../widgets/home_action_grid.dart';
import 'add_work_log_screen.dart';
import 'clients_screen.dart';

class OrderStatus {
  static const pending = 'pending';
  static const material = 'material';
  static const assembly = 'assembly';
  static const delivery = 'delivery';
  static const completed = 'completed';
  static const canceled = 'canceled';
  
  static const activeStatuses = [pending, material, assembly, delivery];
}

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
  String _positionName = 'Hodim';
  
  Map<String, dynamic> _customPermissions = {};
  Map<String, dynamic> _rolePermissions = {};

  double _displayEarned = 0;
  double _displayWithdrawn = 0;
  
  // For Admin 
  double _companyCash = 0;
  double _workerDebt = 0;
  int _pendingApprovalsCount = 0;
  int _totalClientsCount = 0;
  int _newClientsCount = 0;

  int _statsCount = 0;
  int _totalOrders = 0;
  int _activeOrders = 0;
  int _unreadNotificationsCount = 0;

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

      // 1. Order Stats (Common for both to display in Grid/Cards)
      final orders = await _supabase.from('orders').select('total_price, status');
      final unreadNotifs = await _supabase.from('notifications').select('id').eq('user_id', user.id).eq('is_read', false);
      
      int actOrds = 0;
      double totalIncome = 0;
      for (var o in orders) {
        totalIncome += (o['total_price'] ?? 0).toDouble();
        if (OrderStatus.activeStatuses.contains(o['status'])) actOrds++;
      }

      // 2. Based on role, calculate specific finance details
      if (hasPermission('can_view_finance') || _isSuperAdmin) {
        // Admin: Korxona umumiy hisob-kitoblari
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
        final allWorks = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
        final pendingWorks = await _supabase.from('work_logs').select('id').eq('is_approved', false);
        final pendingAvans = await _supabase.from('withdrawals').select('id').eq('status', 'pending');
        final clientsRes = await _supabase.from('clients').select('id, created_at');
        final workers = await _supabase.from('profiles').select('id').eq('is_super_admin', false);

        double totalPaid = 0;
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        double totalWorksSum = 0;
        for (var w in allWorks) totalWorksSum += (w['total_sum'] ?? 0).toDouble();

        final dayAgo = DateTime.now().subtract(const Duration(days: 1));
        final recentOnes = clientsRes.where((c) => DateTime.parse(c['created_at']).isAfter(dayAgo)).length;

        // Adminning SHAXSIY ishlari va olgan pullari (Admin ham ish haqiga ega!)
        final myWorks = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final myWithdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
        
        double myEarned = 0;
        double myPaid = 0;
        for (var w in myWorks) myEarned += (w['total_sum'] ?? 0).toDouble();
        for (var w in myWithdraws) myPaid += (w['amount'] ?? 0).toDouble();

        // YANGI LUG'AT YORDAMIDA RAHBAR (Global bonus)
        if (profile != null && (profile['is_super_admin'] == true || (profile['app_roles'] != null && profile['app_roles']['role_type'] == 'aup'))) {
          double globalBonusLimit = 0;
          if (profile['custom_permissions'] != null && profile['custom_permissions']['global_bonus_m2'] != null) {
            globalBonusLimit = (profile['custom_permissions']['global_bonus_m2']).toDouble();
          }

          if (globalBonusLimit > 0) {
            double totalCompletedArea = 0;
            for (var o in orders) {
              if (o['status'] == 'completed') {
                totalCompletedArea += (o['total_area_m2'] ?? 0).toDouble();
              }
            }
            myEarned += (totalCompletedArea * globalBonusLimit);
          }
        }

        if (mounted) {
          setState(() {
            _companyCash = totalIncome - totalPaid;
            _workerDebt = totalWorksSum - totalPaid;
            _totalOrders = orders.length;
            _activeOrders = actOrds;
            _pendingApprovalsCount = pendingWorks.length + pendingAvans.length;
            _totalClientsCount = clientsRes.length;
            _newClientsCount = recentOnes;
            _statsCount = myWorks.length; // Adminning shaxsiy bajarilgan ishlari soni
            
            // Adminning Shaxsiy maoshi va pullari
            _displayEarned = myEarned; 
            _displayWithdrawn = myPaid;
            _unreadNotificationsCount = unreadNotifs.length;
          });
        }
      } else {
        // Worker
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id).eq('is_approved', true);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
            
        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _displayEarned = earned;
            _displayWithdrawn = paid;
            _statsCount = works.length; 
            _totalOrders = orders.length; 
            _activeOrders = actOrds;
            _pendingApprovalsCount = 0;
            _totalClientsCount = 0;
            _newClientsCount = 0;
            _companyCash = 0;
            _workerDebt = 0;
            _unreadNotificationsCount = unreadNotifs.length;
          });
        }
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Xayrli tong";
    if (h < 17) return "Xayrli kun";
    return "Xayrli kech";
  }

  void _showWithdrawDialog() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Avans so'rash", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Summa (so'm)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: "Izoh (masalan: Yo'l kira uchun)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting 
                    ? null 
                    : () async {
                        final amtText = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        if (amtText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Summani kiriting")));
                          return;
                        }
                        
                        setModalState(() => isSubmitting = true);
                        
                        try {
                          final user = _supabase.auth.currentUser;
                          if (user == null) throw Exception("Foydalanuvchi topilmadi");
                          
                          final res = await _supabase.from('withdrawals').insert({
                            'worker_id': user.id,
                            'amount': double.parse(amtText),
                            'description': descCtrl.text.trim().isEmpty ? 'Avans so\'rovi' : descCtrl.text.trim(),
                            'status': 'pending', 
                            'created_by_admin': false,
                          }).select().single();
                          
                          // Adminlarga bildirishnoma yuborish
                          final admins = await _supabase.from('profiles').select('id').eq('is_super_admin', true);
                          for (var a in admins) {
                            await _supabase.from('notifications').insert({
                              'user_id': a['id'],
                              'title': 'Yangi Avans So\'rovi',
                              'body': '${_userName} (Hodim) ${amtText} so\'m so\'ramoqda.',
                              'type': 'withdrawal',
                              'target_id': res['id'].toString(),
                            });
                          }
                          
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov yuborildi! Kutilmoqda.")));
                            _loadAllData(); // Ma'lumotlarni yangilash 
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                          }
                        } finally {
                          setModalState(() => isSubmitting = false);
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, 
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                  ),
                  child: isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("So'rov yuborish"),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isAdminView = hasPermission('can_view_finance') || _isSuperAdmin;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAllData,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  children: [
                    // 1. Tepa qism (Home Header)
                    HomeHeader(
                      greeting: _greeting, 
                      userName: "$_userName ($_positionName)",
                      unreadCount: _unreadNotificationsCount,
                    ),
                    const SizedBox(height: 25),
                    
                    // 2. Katta Kassa Kartasi (Balance Card)
                    BalanceCard(
                      role: isAdminView ? 'admin' : 'worker', 
                      companyCash: _companyCash, 
                      workerDebt: _workerDebt,
                      personalEarned: _displayEarned,
                      personalPaid: _displayWithdrawn,
                      statsCount: _statsCount,
                    ),
                    
                    const SizedBox(height: 25),
                    
                    // 3. Ish topshirish tugmasi
                    if (hasPermission('can_add_work_log') || _userRoleType == 'worker') ...[
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E5BFF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 3,
                          ),
                          icon: const Icon(Icons.add_task_rounded, size: 26),
                          label: const Text("Bajargan ishni topshirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const AddWorkLogScreen())
                            ).then((value) {
                              _loadAllData();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 25),
                    ],
                    
                    // 4. Tezkor Tugmalar (Action Grid)
                    HomeActionGrid(
                      isAdmin: isAdminView,
                      canManageUsers: _isSuperAdmin || hasPermission('can_manage_users'),
                      totalOrders: _totalOrders,
                      activeOrders: _activeOrders,
                      pendingApprovalsCount: _pendingApprovalsCount,
                      totalClientsCount: _totalClientsCount,
                      newClientsCount: _newClientsCount,
                      showWithdrawOption: !isAdminView || hasPermission('can_withdraw'), // Worker or explicitly allowed
                      onWithdrawTap: _showWithdrawDialog,
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
