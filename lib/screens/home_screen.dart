import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'manage_users_screen.dart'; // Rol boshqarish sahifasi
import 'package:flutter/services.dart'; // Status bar rangi uchun kerak

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _userName = '';
  String _userRole = 'worker'; // Default rol
  String _userId = '';
  double _totalEarned = 0;
  double _totalWithdrawn = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      final workLogs = await _supabase.from('work_logs').select().eq('worker_id', _userId);
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', _userId);

      double earned = 0, withdrawn = 0;
      for (var log in workLogs) {
        if (log['is_approved'] == true) earned += (log['total_sum'] ?? 0).toDouble();
      }
      for (var w in withdrawals) withdrawn += (w['amount'] ?? 0).toDouble();

      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _totalEarned = earned;
        _totalWithdrawn = withdrawn;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
            // --- [ YANGILANGAN HEADER BAR ] ---
      appBar: AppBar(
        backgroundColor: Colors.blue.shade900, // To'q ko'k rang (Brend)
        elevation: 0, // Soyani olib tashlaymiz (zamonaviy flat dizayn)
        toolbarHeight: 70, // Biroz balandroq qilamiz
        
        // Status bar rangini to'g'irlash (Soat va zaryad oq rangda bo'ladi)
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light, 
        ),

        // 1. CHAP TOMON: Ism va Rol
        title: Row(
          children: [
            // Avatarka o'rniga Ikonka
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _userRole == 'admin' ? Icons.workspace_premium : Icons.person,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            
            // Ism va Rol matnlari
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName.isNotEmpty ? _userName : "Yuklanmoqda...",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                // Rol uchun kichkina "Badge"
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _userRole == 'admin' ? Colors.amber : Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _userRole.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ],
        ),

        // 2. O'NG TOMON: Tugmalar
        actions: [
          // Yangilash tugmasi
          IconButton(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: "Yangilash",
          ),
          
          // Chiqish menyusi (Pop-up Menu)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'logout') {
                await _supabase.auth.signOut();
                if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [Icon(Icons.person, color: Colors.blue), SizedBox(width: 10), Text("Profil sozlamalari")],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 10), Text("Chiqish")],
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildBalanceCard(),
              const SizedBox(height: 20),
              
              // ISH QO'SHISH TUGMASI
              Row(
                children: [
                  _buildMenuBtn("Ish Qo'shish", Icons.add_circle, Colors.blue, _showWorkDialog),
                ],
              ),
              
              // ADMIN PANEL
              if (_userRole == 'admin') ...[
                const SizedBox(height: 30),
                const Divider(),
                const Text("ADMIN PANEL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildMenuBtn("Tasdiqlash", Icons.fact_check, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                    }),
                    const SizedBox(width: 10),
                    _buildMenuBtn("Pul Berish", Icons.payments, Colors.green, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWithdrawalScreen()));
                    }),
                  ],
                ),
                const SizedBox(height: 10),
                // XODIMLARNI BOSHQARISH TUGMASI
                Row(
                  children: [
                    _buildMenuBtn("Xodimlar & Rollar", Icons.manage_accounts, Colors.orange, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageUsersScreen()));
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade900, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        const Text("Sof Qoldiq", style: TextStyle(color: Colors.white70)),
        Text("${(_totalEarned - _totalWithdrawn).toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildMenuBtn(String t, IconData i, Color c, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap, icon: Icon(i), label: Text(t), 
        style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15))
      )
    );
  }

  // --- [ ENG MUHIM QISM: ISH QO'SHISH ] ---
  void _showWorkDialog() async {
    // 1. Zakazlarni yuklaymiz
    final orders = await _supabase.from('orders').select();
    
    // 2. Ish turlarini yuklaymiz (ROLGA QARAB FILTRLAYMIZ)
    // Agar admin bo'lsa hammasini ko'radi. 
    // Agar boshqa bo'lsa, faqat 'worker' (umumiy) va o'zining roli (masalan 'painter')ni ko'radi.
    var taskQuery = _supabase.from('task_types').select();
    
    // Filtr logika (hozircha oddiy)
    // Agar ro'yxat bo'sh bo'lmasligi uchun filtrni ehtiyotkor qo'yamiz
    final taskTypes = await taskQuery; 

    if (!mounted) return;

    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text("Ishni Kiritish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              const SizedBox(height: 25),
              
              // ZAKAZNI TANLASH
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Zakazni tanlang", border: OutlineInputBorder()),
                items: orders.map((o) => DropdownMenuItem(
                  value: o['id'].toString(), 
                  child: Text("${o['order_number']} (${o['total_area_m2'] ?? 0} m²)")
                )).toList(),
                onChanged: (v) {
                  selectedOrderId = v;
                  // AVTOMATIK KVADRATNI TO'LDIRISH
                  final selectedOrder = orders.firstWhere((o) => o['id'].toString() == v);
                  setModalState(() {
                    areaController.text = selectedOrder['total_area_m2']?.toString() ?? "0";
                  });
                },
              ),
              const SizedBox(height: 15),
              
              // ISH TURINI TANLASH
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(
                  value: t, 
                  child: Text("${t['name']} (${t['default_rate']} so'm) - ${t['target_role'] ?? 'worker'}")
                )).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 15),
              
              // KVADRAT (READ ONLY - O'ZGARTIRIB BO'LMAYDI)
              TextField(
                controller: areaController,
                readOnly: true, // QULF
                decoration: InputDecoration(
                  labelText: "Hajmi (m²) - Bek tomonidan belgilangan", 
                  filled: true, fillColor: Colors.grey.shade200,
                  border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock)
                ),
              ),
              
              // HISOB-KITOB
              if (selectedTask != null && areaController.text.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  "Jami: ${(double.tryParse(areaController.text) ?? 0) * (selectedTask!['default_rate'] ?? 0)} so'm",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                ),
              ],

              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  if (selectedOrderId == null || selectedTask == null || areaController.text.isEmpty) return;
                  await _supabase.from('work_logs').insert({
                    'worker_id': _userId,
                    'order_id': int.parse(selectedOrderId!),
                    'task_type': selectedTask!['name'],
                    'area_m2': double.parse(areaController.text),
                    'rate': selectedTask!['default_rate'],
                    'is_approved': _userRole == 'admin', 
                  });
                  if (mounted) { Navigator.pop(context); _loadAllData(); }
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                child: const Text("SAQLASH"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
