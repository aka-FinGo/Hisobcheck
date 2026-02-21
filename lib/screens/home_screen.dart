import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// --- VIDJETLAR ---
import '../widgets/pwa_prompt.dart';

class AppRoles {
  static const admin = 'admin';
  static const worker = 'worker';
  static const installer = 'installer';
}

/// Bosh sahifa. [onNavigateToTab] berilsa, pastdagi menyudagi tab ga o'tish mumkin (0=Asosiy, 1=Mijozlar, 2=Zakazlar, 3=Hisobot, 4=Profil).
class HomeScreen extends StatefulWidget {
  final void Function(int index)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _userRole = AppRoles.worker;
  String _userName = '';

  // Admin statistikasi
  int _activeOrders = 0;
  double _totalIncome = 0;

  // Ishchi statistikasi
  double _workerEarned = 0;
  double _workerWithdrawn = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // PWA (Ekranga o'rnatish) oynasini chaqirish
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) checkAndShowPwaPrompt(context);
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      _userRole = profile['role'] ?? AppRoles.worker;
      _userName = profile['full_name'] ?? 'Foydalanuvchi';

      if (_userRole == AppRoles.admin) {
        // Admin uchun jami zakaz pullari
        final orders = await _supabase.from('orders').select('status, total_price');
        int active = 0;
        double income = 0;
        for(var o in orders) {
          if(o['status'] != 'completed' && o['status'] != 'canceled') active++;
          income += (o['total_price'] ?? 0).toDouble();
        }
        if (mounted) {
          setState(() {
            _activeOrders = active;
            _totalIncome = income;
          });
        }
      } else {
        // Ishchi uchun ishlab topilgan pullar
        final works = await _supabase.from('work_logs').select('total_sum').eq('worker_id', user.id);
        final withdraws = await _supabase.from('withdrawals').select('amount').eq('worker_id', user.id).eq('status', 'approved');
        double earned = 0;
        double paid = 0;
        for (var w in works) earned += (w['total_sum'] ?? 0).toDouble();
        for (var w in withdraws) paid += (w['amount'] ?? 0).toDouble();
        
        if (mounted) {
          setState(() {
            _workerEarned = earned;
            _workerWithdrawn = paid;
          });
        }
      }
    } catch (e) {
      debugPrint("Load error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ISH TOPSHIRISH DIALOGI ---
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedOrder == null || selectedTask == null) return;
                  try {
                    await _supabase.from('work_logs').insert({
                      'worker_id': _supabase.auth.currentUser!.id,
                      'order_id': selectedOrder,
                      'task_type': selectedTask!['name'],
                      'area_m2': double.tryParse(areaController.text) ?? 0,
                      'rate': selectedTask!['default_rate'],
                      'description': notesController.text,
                    });

                    if (selectedTask!['target_status'] != null && selectedTask!['target_status'].toString().isNotEmpty) {
                      await _supabase.from('orders').update({'status': selectedTask!['target_status']}).eq('id', selectedOrder);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      _loadData(); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish qabul qilindi!"), backgroundColor: Colors.green));
                    }
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                  }
                },
                child: const Text("TOPSHIRISH", style: TextStyle(fontWeight: FontWeight.bold)),
              ))
            ],
          ),
        ),
      ),
    );
  }

  // --- PUL SO'RASH DIALOGI ---
  void _showWithdrawDialog() {
    final amountController = TextEditingController();
    double currentBalance = _workerEarned - _workerWithdrawn;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pul so'rash"),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
            onPressed: () async {
              double amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              
              await _supabase.from('withdrawals').insert({
  'worker_id': _supabase.auth.currentUser!.id,
  'amount': amount,
  'status': 'pending'
});
              
              if (mounted) {
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("So'rov yuborildi! Kuting."), backgroundColor: Colors.blue));
              }
            },
            child: const Text("YUBORISH"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Salom, $_userName!", style: const TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold, fontSize: 20)),
            Text(_welcomeSubtitle(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2E5BFF)), onPressed: _loadData),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E5BFF)))
        : RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF2E5BFF),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                if (_userRole == AppRoles.admin) _buildAdminCard(),
                if (_userRole != AppRoles.admin) _buildWorkerCard(),
                const SizedBox(height: 28),
                _sectionTitle('Tez harakatlar'),
                const SizedBox(height: 12),
                if (_userRole == AppRoles.admin) _buildAdminQuickActions(),
                if (_userRole != AppRoles.admin) _buildWorkerQuickActions(),
              ],
            ),
          ),
    );
  }

  String _welcomeSubtitle() {
    final now = DateTime.now();
    return DateFormat('d MMMM, EEEE').format(now);
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2D3142),
      ),
    );
  }

  /// Admin: Mijozlar, Zakazlar, Hisobot, Profil — kartochkalar
  Widget _buildAdminQuickActions() {
    final items = [
      {'icon': Icons.people_rounded, 'label': 'Mijozlar', 'color': const Color(0xFF2E5BFF), 'tab': 1},
      {'icon': Icons.list_alt_rounded, 'label': 'Zakazlar', 'color': const Color(0xFF5C6BC0), 'tab': 2},
      {'icon': Icons.bar_chart_rounded, 'label': 'Hisobot', 'color': const Color(0xFF00BFA5), 'tab': 3},
      {'icon': Icons.person_rounded, 'label': 'Profil', 'color': const Color(0xFF78909C), 'tab': 4},
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.15,
      children: items.map<Widget>((e) => _quickActionCard(
        icon: e['icon'] as IconData,
        label: e['label'] as String,
        color: e['color'] as Color,
        onTap: () => widget.onNavigateToTab?.call(e['tab'] as int),
      )).toList(),
    );
  }

  /// Ishchi: Ish topshirish va Pul so'rash — 2 ta katta kartochka
  Widget _buildWorkerQuickActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                icon: Icons.add_task_rounded,
                label: "Ish topshirish",
                color: const Color(0xFF2E5BFF),
                onTap: _showWorkDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _quickActionCard(
                icon: Icons.account_balance_wallet_rounded,
                label: "Pul so'rash",
                color: const Color(0xFF00C853),
                onTap: _showWithdrawDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      shadowColor: color.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3142)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ADMIN UCHUN KARTA ---
  Widget _buildAdminCard() {
    final fmt = NumberFormat("#,###").format(_totalIncome).replaceAll(',', ' ');
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2E5BFF), Color(0xFF1441E6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Umumiy Kutilayotgan Daromad", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Text("$fmt so'm", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.timelapse, color: Colors.white70, size: 16),
              const SizedBox(width: 5),
              Text("Jarayondagi buyurtmalar: $_activeOrders ta", style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }

  // --- ISHCHI UCHUN KARTA ---
  Widget _buildWorkerCard() {
    double balance = _workerEarned - _workerWithdrawn;
    final fmt = NumberFormat("#,###");
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mening shaxsiy balansim", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          Text("${fmt.format(balance).replaceAll(',', ' ')} so'm", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Ishlagan", fmt.format(_workerEarned).replaceAll(',', ' '), Icons.arrow_downward, Colors.greenAccent),
              _miniStat("Olgan", fmt.format(_workerWithdrawn).replaceAll(',', ' '), Icons.arrow_upward, Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

}
