import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Sahifalarni import qilish
import 'login_screen.dart';
import 'admin_approvals.dart';
import 'add_withdrawal.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';
import 'remnant_screen.dart'; // LDSP qoldiqlari sahifasi

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- [ 1. SOZLAMALAR VA O'ZGARUVCHILAR ] ---
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  String _userName = '';
  String _userRole = 'worker';
  String _userId = '';

  double _totalEarned = 0;    // Jami ishlagan puli
  double _totalWithdrawn = 0; // Jami olgan puli (avans)
  double _pendingAmount = 0;  // Tasdiq kutilayotgan pullar

  @override
  void initState() {
    super.initState();
    _loadAllData(); // Dastur ochilishi bilan ma'lumotlarni yuklash
  }

  // --- [ 2. MA'LUMOTLARNI YUKLASH (DATABASE LOGIC) ] ---
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      _userId = user.id;

      // Foydalanuvchi profilini olish (Ismi va Roli)
      final profile = await _supabase.from('profiles').select().eq('id', _userId).single();
      
      // Ishlar va To'lovlar ro'yxatini olish
      final workLogs = await _supabase.from('work_logs').select().eq('worker_id', _userId);
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', _userId);

      double earned = 0;
      double pending = 0;
      for (var log in workLogs) {
        if (log['is_approved'] == true) {
          earned += (log['total_sum'] ?? 0).toDouble();
        } else {
          pending += (log['total_sum'] ?? 0).toDouble();
        }
      }

      double withdrawn = 0;
      for (var w in withdrawals) {
        withdrawn += (w['amount'] ?? 0).toDouble();
      }

      setState(() {
        _userName = profile['full_name'] ?? 'Xodim';
        _userRole = profile['role'] ?? 'worker';
        _totalEarned = earned;
        _totalWithdrawn = withdrawn;
        _pendingAmount = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Ma'lumot yuklashda xato: $e");
    }
  }

  // --- [ 3. AKKAUNTDAN CHIQISH FUNKSIYASI ] ---
  Future<void> _handleSignOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // --- 2-QISM (UI VA TUGMALAR) PASTDA ---
  // --- [ 4. ASOSIY EKRAN QURILISHI (BUILD) ] ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(_userRole == 'admin' ? "Admin: $_userName" : "Hisob: $_userName"),
        actions: [
          IconButton(onPressed: _handleSignOut, icon: const Icon(Icons.logout, color: Colors.red)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- BALANS KARTASI ---
              _buildBalanceCard(),
              const SizedBox(height: 25),
              
              const Align(alignment: Alignment.centerLeft, child: Text(" MENYU", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(height: 10),

              // --- 1-QATOR TUGMALARI: ISH VA TARIX ---
              Row(
                children: [
                  _buildMenuBtn("Ish Qo'shish", Icons.add_box, Colors.blue, _showWorkDialog),
                  const SizedBox(width: 12),
                  _buildMenuBtn("Tarix", Icons.history, Colors.grey.shade800, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
                  }),
                ],
              ),
              const SizedBox(height: 12),

              // --- 2-QATOR TUGMALARI: HAMYON VA QOLDIQLAR ---
              Row(
                children: [
                  _buildMenuBtn("Hamyon", Icons.wallet, Colors.green.shade700, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen()));
                  }),
                  const SizedBox(width: 12),
                  _buildMenuBtn("Qoldiqlar", Icons.inventory_2, Colors.brown, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RemnantScreen()));
                  }),
                ],
              ),
              
              // --- [ 5. ADMIN BO'LIMI (Faqat admin ko'radi) ] ---
              if (_userRole == 'admin') ...[
                const SizedBox(height: 35),
                const Divider(thickness: 1),
                const Text("ADMINISTRATOR BOSHQARUVI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 12)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildMenuBtn("Tasdiqlash", Icons.fact_check, Colors.purple, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminApprovalsScreen()));
                    }),
                    const SizedBox(width: 12),
                    _buildMenuBtn("Pul Berish", Icons.send_money, Colors.teal, () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AddWithdrawalScreen()));
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

  // --- [ 6. YORDAMCHI VIDJETLAR (HELPER WIDGETS) ] ---

  // Balans kartasi (Dizayn)
  Widget _buildBalanceCard() {
    double balance = _totalEarned - _totalWithdrawn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: _userRole == 'admin' ? Colors.red.shade900 : Colors.blue.shade900,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          const Text("Joriy Hisobingiz", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 5),
          Text("${balance.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Ishlangan", _totalEarned, Colors.greenAccent),
              _miniStat("Olingan", _totalWithdrawn, Colors.orangeAccent),
            ],
          ),
          if (_pendingAmount > 0) ...[
            const SizedBox(height: 10),
            Text("Kutilmoqda: ${_pendingAmount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
          ]
        ],
      ),
    );
  }

  Widget _miniStat(String label, double val, Color col) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      Text("${val.toStringAsFixed(0)}", style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  // Umumiy tugma vidjeti
  Widget _buildMenuBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 8),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // --- [ 7. ISH QO'SHISH MODAL OYNASI ] ---
  void _showWorkDialog() async {
    final orders = await _supabase.from('orders').select();
    final taskTypes = await _supabase.from('task_types').select();

    if (!mounted) return;

    String? selectedOrderId;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 25, left: 25, right: 25, top: 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Bajarilgan ishni kiritish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Zakaz raqami", border: OutlineInputBorder()),
                items: orders.map((o) => DropdownMenuItem(value: o['id'].toString(), child: Text(o['order_number']))).toList(),
                onChanged: (v) => selectedOrderId = v,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Ish turi", border: OutlineInputBorder()),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text(t['name']))).toList(),
                onChanged: (v) => setModalState(() => selectedTask = v),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: areaController,
                decoration: const InputDecoration(labelText: "Hajmi (m2)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.straighten)),
                keyboardType: TextInputType.number,
                onChanged: (_) => setModalState(() {}),
              ),
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
                child: const Text("BAZAGA YUBORISH"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
