import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_users_screen.dart';   
import 'clients_screen.dart';        
import 'admin_finance_screen.dart';
import 'user_profile_screen.dart';
import '../widgets/balance_card.dart'; // Sizning animatsiyali kartangiz
import '../widgets/reload_button.dart'; // Sizning yangilash tugmangiz

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // User Info
  String _userRole = 'worker';
  String _userName = '';
  
  // BalanceCard uchun ma'lumotlar (Universal)
  double _displayEarned = 0;   // Admin uchun: Jami Kirim | Ishchi uchun: Ishlagan puli
  double _displayWithdrawn = 0; // Admin uchun: Jami Xarajat | Ishchi uchun: Olgan puli
  
  // Admin uchun qo'shimcha statistika
  int _totalOrders = 0;
  int _activeOrders = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // --- 1. MA'LUMOTLARNI YUKLASH (ENG MUHIM QISM) ---
  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Profilni yuklash
      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? 'worker';
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == 'admin') {
        // --- ADMIN LOGIKASI (KORXONA KASSASI) ---
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');

        double totalIncome = 0;
        double totalPaid = 0;

        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            _displayEarned = totalIncome;    // Kirim
            _displayWithdrawn = totalPaid;   // Chiqim
            _totalOrders = orders.length;
            _activeOrders = orders.where((o) => o['status'] != 'completed' && o['status'] != 'canceled').length;
            _isLoading = false;
          });
        }
      } else {
        // --- ISHCHI LOGIKASI (SHAXSIY BALANS) ---
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('user_id', user.id).eq('status', 'approved');

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
      debugPrint("Xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. PUL SO'RASH DIALOGI ---
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
            Text("Mavjud balans: ${currentBalance.toStringAsFixed(0)} so'm", 
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
              double amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              
              // Bazaga so'rov yuborish
              await _supabase.from('withdrawals').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'amount': amount,
                'status': 'pending'
              });
              
              if (mounted) {
                Navigator.pop(ctx);
                _loadAllData(); // Yangilash
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov yuborildi!"), backgroundColor: Colors.blue));
              }
            },
            child: const Text("YUBORISH"),
          )
        ],
      ),
    );
  }

  // --- 3. ISH TOPSHIRISH DIALOGI ---
  void _showWorkDialog() async {
    final ordersResp = await _supabase.from('orders').select('*, clients(full_name)').neq('status', 'completed').order('created_at', ascending: false);
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
              
              // Zakaz tanlash
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

              // Ish turi
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
                  if (selectedOrder == null || selectedTask == null) return;
                  try {
                    // Ishni yozish
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id': selectedOrder,
                      'task_type': selectedTask!['name'],
                      'area_m2': double.tryParse(areaController.text) ?? 0,
                      'rate': selectedTask!['default_rate'],
                      'description': notesController.text,
                    });

                    // Avto Status
                    if (selectedTask!['target_status'] != null && selectedTask!['target_status'].toString().isNotEmpty) {
                      await _supabase.from('orders').update({'status': selectedTask!['target_status']}).eq('id', selectedOrder);
                    } else if (_userRole == 'installer') {
                       await _supabase.from('orders').update({'status': 'completed'}).eq('id', selectedOrder);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadAllData(); // YANGILASH
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish qabul qilindi!"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
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
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(_userRole == 'admin' ? "Boshqaruv Paneli" : "Ishchi Kabineti"),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          ReloadButton(onPressed: _loadAllData), // Sizning tugmangiz
          IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen())), icon: const Icon(Icons.person_outline)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadAllData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 1. ADMIN UCHUN QO'SHIMCHA STATISTIKA
                  if (_userRole == 'admin') 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        children: [
                          _miniCard("Jami Zakaz", "$_totalOrders", Colors.blue),
                          const SizedBox(width: 10),
                          _miniCard("Jarayonda", "$_activeOrders", Colors.orange),
                        ],
                      ),
                    ),

                  // 2. BALANS KARTASI (HAMMA UCHUN)
                  // Admin uchun: Earned = Kirim, Withdrawn = Xarajat
                  // Ishchi uchun: Earned = Ishlagani, Withdrawn = Olgani
                  BalanceCard(
                    earned: _displayEarned,
                    withdrawn: _displayWithdrawn,
                    role: _userRole,
                    onStatsTap: () {
                      if (_userRole == 'admin') {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen()));
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // 3. MENYU TUGMALARI
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      _menuItem(Icons.people, "Mijozlar", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
                      
                      if (_userRole != 'admin')
                        _menuItem(Icons.add_task, "Ish Topshirish", Colors.blue, _showWorkDialog),
                      
                      if (_userRole != 'admin')
                        _menuItem(Icons.account_balance_wallet, "Pul so'rash", Colors.green, _showWithdrawDialog),

                      if (_userRole == 'admin') ...[
                        _menuItem(Icons.manage_accounts, "Xodimlar", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
                        _menuItem(Icons.payments, "Moliya Bo'limi", Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen()))),
                      ]
                    ],
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _miniCard(String title, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
