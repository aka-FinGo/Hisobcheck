import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_users_screen.dart';   
import 'clients_screen.dart';        
import 'stats_screen.dart'; 
import 'user_profile_screen.dart';
import '../widgets/balance_card.dart'; 
import '../widgets/reload_button.dart';
import '../widgets/menu_button.dart';
import '../widgets/mini_stat_card.dart';
import '../widgets/big_action_button.dart';
import 'admin_finance_screen.dart';
// --- 🟢 CONSTANTLAR (Magic String'larni yo'qotish uchun) ---
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
// -------------------------------------------------------------

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

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == AppRoles.admin) {
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');

        double totalIncome = 0;
        double totalPaid = 0;

        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;    
            _displayWithdrawn = totalPaid;   
            _totalOrders = orders.length;
            _activeOrders = orders.where((o) => o['status'] != OrderStatus.completed && o['status'] != OrderStatus.canceled).length;
            _isLoading = false;
          });
        }
      } else {
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id);
        // 🔴 KRITIK TUZATISH: user_id o'rniga worker_id ishlatildi
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');

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
      // 🟡 XATOLIKNI YUTIB YUBORMASLIK
      debugPrint("Ma'lumot yuklashda xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    double currentBalance = _displayEarned - _displayWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pul so'rash (Avans)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mavjud: ${currentBalance.toStringAsFixed(0)} so'm", 
                 style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 15),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Summa", border: OutlineInputBorder(), suffixText: "so'm"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
            onPressed: () async {
              // 🟡 SQL INJECTION / CRASH OLDINI OLISH
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Noto'g'ri summa!")));
                 return;
              }
              if (amount > currentBalance) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Balans yetarli emas!")));
                 return;
              }
              
              try {
                await _supabase.from('withdrawals').insert({
                  'worker_id': _supabase.auth.currentUser!.id, // 🔴 KRITIK TUZATISH
                  'amount': amount,
                  'status': OrderStatus.pending // Constant
                });
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadAllData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov yuborildi!"), backgroundColor: Colors.blue));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("So'rov yuborishda xato: $e"), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text("YUBORISH"),
          )
        ],
      ),
    );
  }

  void _showWorkDialog() async {
    final ordersResp = await _supabase.from('orders').select('*, clients(full_name)').neq('status', OrderStatus.completed).order('created_at', ascending: false);
    final taskTypesResp = await _supabase.from('task_types').select();

    if (!mounted) return;
    final orders = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

    dynamic selectedOrder;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController(); 
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ish Topshirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(labelText: "Zakaz", border: OutlineInputBorder()),
                isExpanded: true,
                items: orders.map((o) => DropdownMenuItem(value: o['id'], child: Text(o['project_name']))).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedOrder = v;
                    final fullOrder = orders.firstWhere((o) => o['id'] == v);
                    areaController.text = (fullOrder['total_area_m2'] ?? 0).toString();
                  });
                },
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text(t['name']))).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 10),

              TextField(controller: areaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Hajm (m²)", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: notesController, decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)", border: OutlineInputBorder())),
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedOrder == null || selectedTask == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barcha maydonlarni to'ldiring!")));
                    return;
                  }
                  
                  try {
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id': selectedOrder,
                      'task_type': selectedTask!['name'],
                      'area_m2': double.tryParse(areaController.text) ?? 0, // Xavfsiz parse
                      'rate': selectedTask!['default_rate'],
                      'description': notesController.text,
                    });

                    if (selectedTask!['target_status'] != null && selectedTask!['target_status'].toString().isNotEmpty) {
                      await _supabase.from('orders').update({'status': selectedTask!['target_status']}).eq('id', selectedOrder);
                    } else if (_userRole == AppRoles.installer) {
                       await _supabase.from('orders').update({'status': OrderStatus.completed}).eq('id', selectedOrder);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadAllData(); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish qabul qilindi!"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                  }
                },
                child: const Text("TOPSHIRISH"),
              ))
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Xush kelibsiz,", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                              Text(_userName, style: const TextStyle(color: Color(0xFF2D3142), fontSize: 24, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(_userName.isNotEmpty ? _userName[0] : "A", style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 25),

                      if (_userRole == AppRoles.admin) ...[
                        Row(
                          children: [
                            MiniStatCard(title: "Jami Zakaz", value: "$_totalOrders", color: Colors.blue, icon: Icons.assignment),
                            const SizedBox(width: 15),
                            MiniStatCard(title: "Jarayonda", value: "$_activeOrders", color: Colors.orange, icon: Icons.timelapse),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],

                      BalanceCard(
                        earned: _displayEarned,
                        withdrawn: _displayWithdrawn,
                        role: _userRole,
                        onStatsTap: () {
                          if (_userRole == AppRoles.admin) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                          }
                        },
                      ),

                      const SizedBox(height: 30),
                      const Text("Bo'limlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                      const SizedBox(height: 15),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 1.1,
                        children: [
                          MenuButton(
                            title: "Mijozlar",
                            icon: Icons.people_outline,
                            color: Colors.orange,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
                          ),
                          
                          if (_userRole == AppRoles.admin) ...[
                            MenuButton(
                              title: "Hisobotlar",
                              icon: Icons.bar_chart,
                              color: Colors.indigo,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                            ),
                            MenuButton(
                              title: "Xodimlar",
                              icon: Icons.manage_accounts_outlined,
                              color: Colors.purple,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen())),
                            ),
                            // MANA SHU TUGMA QO'SHILDI:
                            MenuButton(
                              title: "Moliya",
                              icon: Icons.account_balance_wallet,
                              color: Colors.teal,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen())),
                            ),
                          ],
                          
                          if (_userRole != AppRoles.admin)
                            MenuButton(
                              title: "Pul so'rash",
                              icon: Icons.account_balance_wallet_outlined,
                              color: Colors.green,
                              onTap: _showWithdrawDialog, 
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: _userRole != AppRoles.admin 
                    ? BigActionButton(
                        text: "ISH TOPSHIRISH",
                        icon: Icons.add_task,
                        color: const Color(0xFF2E5BFF),
                        onPressed: _showWorkDialog,
                      )
                    : BigActionButton(
                        text: "YANGI MIJOZ QO'SHISH",
                        icon: Icons.person_add,
                        color: const Color(0xFF00C853),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
                      ),
                ),
              ],
            ),
          ),
    );
  }
}
