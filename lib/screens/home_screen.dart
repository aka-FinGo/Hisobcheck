import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'manage_users_screen.dart';   // Xodimlar boshqaruvi
import 'clients_screen.dart';        // Mijozlar
import 'admin_finance_screen.dart';  // <--- YANGI MOLIYA SAHIFASI ULANDI

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
  
  // Worker Stats
  double _myBalance = 0;
  double _earnedTotal = 0;
  double _paidTotal = 0;
  
  // Admin Stats
  int _totalOrders = 0;
  int _activeOrders = 0;
  double _companyBalance = 0; // Taxminiy kassa

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Profil va Rolni olish
      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? 'worker';
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == 'admin') {
        // --- ADMIN STATISTIKASI ---
        final orders = await _supabase.from('orders').select('total_price, status');
        final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');

        double totalIncome = 0;
        double totalPaid = 0;

        for (var o in orders) totalIncome += (o['total_price'] ?? 0).toDouble();
        for (var w in withdrawals) totalPaid += (w['amount'] ?? 0).toDouble();

        _totalOrders = orders.length;
        _activeOrders = orders.where((o) => o['status'] != 'completed').length;
        _companyBalance = totalIncome - totalPaid; // Oddiy kassa hisobi
      } else {
        // --- ISHCHI BALANSI ---
        // 1. Ishlagan pullari
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id);
        double earned = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();

        // 2. Olgan pullari (Tasdiqlanganlari)
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('user_id', user.id).eq('status', 'approved');
        double paid = 0;
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();

        _earnedTotal = earned;
        _paidTotal = paid;
        _myBalance = earned - paid;
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ISHCHI UCHUN: PUL SO'RASH DIALOGI ---
  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pul so'rash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mavjud balans: ${_myBalance.toStringAsFixed(0)} so'm", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 10),
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
            onPressed: () async {
              double amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              if (amount > _myBalance) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Balans yetarli emas!"), backgroundColor: Colors.red));
                return;
              }

              try {
                await _supabase.from('withdrawals').insert({
                  'user_id': _supabase.auth.currentUser!.id,
                  'amount': amount,
                  'status': 'pending'
                });
                
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov adminga yuborildi!"), backgroundColor: Colors.blue));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SO'RASH"),
          )
        ],
      ),
    );
  }

  // --- ISH TOPSHIRISH DIALOGI (AVTO STATUS BILAN) ---
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
    double currentTotal = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Ish Topshirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // ZAKAZ TANLASH
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(labelText: "Zakaz", border: OutlineInputBorder()),
                isExpanded: true,
                items: orders.map((o) => DropdownMenuItem(value: o['id'], child: Text("${o['project_name']}"))).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedOrder = v;
                    final fullOrder = orders.firstWhere((o) => o['id'] == v);
                    areaController.text = (fullOrder['total_area_m2'] ?? 0).toString();
                  });
                },
              ),
              const SizedBox(height: 10),

              // ISH TURI
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text(t['name']))).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedTask = v;
                    double area = double.tryParse(areaController.text) ?? 0;
                    currentTotal = area * (v?['default_rate'] ?? 0);
                  });
                },
              ),
              const SizedBox(height: 10),

              TextField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hajm (m²)", border: OutlineInputBorder()),
                onChanged: (v) {
                   setModalState(() {
                    double area = double.tryParse(v) ?? 0;
                    currentTotal = area * (selectedTask?['default_rate'] ?? 0);
                  });
                }
              ),
              const SizedBox(height: 10),
              
              if (currentTotal > 0)
                 Text("Tahminiy summa: ${currentTotal.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                 
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedOrder == null || selectedTask == null) return;
                  try {
                    // 1. Ishni yozish (TOTAL_SUM YO'Q - Baza hisoblaydi)
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id': selectedOrder,
                      'task_type': selectedTask!['name'],
                      'area_m2': double.tryParse(areaController.text) ?? 0,
                      'rate': selectedTask!['default_rate'],
                      'description': notesController.text,
                    });

                    // 2. AVTOMATIK STATUS O'ZGARTIRISH
                    if (selectedTask!['target_status'] != null && selectedTask!['target_status'].toString().isNotEmpty) {
                      await _supabase.from('orders').update({
                        'status': selectedTask!['target_status']
                      }).eq('id', selectedOrder);
                    } else if (_userRole == 'installer') {
                         await _supabase.from('orders').update({'status': 'completed'}).eq('id', selectedOrder);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadData();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish topshirildi!"), backgroundColor: Colors.green));
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
      backgroundColor: Colors.blue.shade900,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
            children: [
              // --- HEADER QISMI ---
              Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Xush kelibsiz, $_userName", style: const TextStyle(color: Colors.white70)),
                            Text(_userRole == 'admin' ? "BOSHQARUV PANELI" : "ISHCHI KABINETI", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        CircleAvatar(child: Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : "U")),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // ADMIN VA ISHCHI UCHUN FARQLI KARTA
                    if (_userRole == 'admin') 
                      _buildAdminStatsCard()
                    else 
                      _buildWorkerBalanceCard(),
                  ],
                ),
              ),

              // --- PASTKI MENYU (GRID) ---
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                  padding: const EdgeInsets.all(20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      // HAMMA UCHUN
                      _menuItem(Icons.people, "Mijozlar", Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen()))),
                      
                      // FAQAT ISHCHILAR UCHUN
                      if (_userRole != 'admin')
                        _menuItem(Icons.add_task, "Ish Topshirish", Colors.blue, _showWorkDialog),

                      // FAQAT ADMIN UCHUN TUGMALAR
                      if (_userRole == 'admin') ...[
                        _menuItem(Icons.manage_accounts, "Xodimlar", Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()))),
                        _menuItem(Icons.account_balance_wallet, "Moliya", Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFinanceScreen()))),
                        _menuItem(Icons.settings, "Sozlamalar", Colors.grey, () {}),
                      ]
                    ],
                  ),
                ),
              )
            ],
          ),
    );
  }

  // ISHCHI BALANS KARTASI (Pul so'rash tugmasi bilan)
  Widget _buildWorkerBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade800, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text("Mening Balansim", style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          Text("${_myBalance.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          ElevatedButton.icon(
            onPressed: _showWithdrawDialog,
            icon: const Icon(Icons.download, size: 18),
            label: const Text("PUL SO'RASH"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.blue.shade900),
          )
        ],
      ),
    );
  }

  // ADMIN STATISTIKA KARTASI
  Widget _buildAdminStatsCard() {
    return Column(
      children: [
        // 1. KASSA
        Container(
           width: double.infinity,
           padding: const EdgeInsets.all(15),
           margin: const EdgeInsets.only(bottom: 10),
           decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: BorderRadius.circular(15)),
           child: Column(
             children: [
               const Text("Taxminiy Kassa", style: TextStyle(color: Colors.white70)),
               Text("${_companyBalance.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
             ],
           ),
        ),
        // 2. ZAKAZLAR
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    const Text("Jami Zakaz", style: TextStyle(color: Colors.white70)),
                    Text("$_totalOrders", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.4), borderRadius: BorderRadius.circular(15)),
                child: Column(
                  children: [
                    const Text("Jarayonda", style: TextStyle(color: Colors.white70)),
                    Text("$_activeOrders", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 30)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}