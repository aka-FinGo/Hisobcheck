import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // Statistika
  double _totalIncome = 0;
  double _totalPaid = 0;
  double _companyBalance = 0;

  // So'rovlar
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);
    try {
      // 1. STATISTIKA
      final orders = await _supabase.from('orders').select('total_price');
      final approvedWithdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');

      double income = 0;
      double paid = 0;
      for (var o in orders) income += (o['total_price'] ?? 0).toDouble();
      for (var w in approvedWithdrawals) paid += (w['amount'] ?? 0).toDouble();

      // 2. KUTILAYOTGAN SO'ROVLAR
      final requests = await _supabase
          .from('withdrawals')
          .select('*, profiles(full_name, phone)') // Kim so'raganini bilish uchun
          .eq('status', 'pending')
          .order('created_at');

      // 3. TARIX (Oxirgi 20 ta)
      final historyRes = await _supabase
          .from('withdrawals')
          .select('*, profiles(full_name)')
          .neq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalPaid = paid;
          _companyBalance = income - paid;
          _pendingRequests = List<Map<String, dynamic>>.from(requests);
          _history = List<Map<String, dynamic>>.from(historyRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SO'ROVNI HAL QILISH ---
  void _processRequest(int id, bool approve) async {
    try {
      await _supabase.from('withdrawals').update({
        'status': approve ? 'approved' : 'rejected'
      }).eq('id', id);
      
      _loadFinanceData(); // Yangilash
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? "To'lov tasdiqlandi" : "Rad etildi"),
        backgroundColor: approve ? Colors.green : Colors.red,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(title: const Text("Moliya va Kassa")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. KATTA KASSA KARTASI
                  _buildCompanyBalanceCard(),
                  const SizedBox(height: 20),

                  // 2. KUTILAYOTGAN SO'ROVLAR
                  const Text("To'lov so'rovlari", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _pendingRequests.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Yangi so'rovlar yo'q"))))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingRequests.length,
                          itemBuilder: (ctx, i) {
                            final req = _pendingRequests[i];
                            return Card(
                              elevation: 3,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(child: Text(req['profiles']?['full_name']?[0] ?? "?")),
                                title: Text(req['profiles']?['full_name'] ?? "Noma'lum"),
                                subtitle: Text("${req['amount']} so'm\nTel: ${req['profiles']?['phone'] ?? '-'}"),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                      onPressed: () => _processRequest(req['id'], true),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                      onPressed: () => _processRequest(req['id'], false),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 20),
                  const Text("So'nggi o'tkazmalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // 3. TARIX
                   ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (ctx, i) {
                      final item = _history[i];
                      bool isApproved = item['status'] == 'approved';
                      return Card(
                        child: ListTile(
                          title: Text(item['profiles']?['full_name'] ?? ""),
                          subtitle: Text(item['created_at'].toString().split('T')[0]),
                          trailing: Text(
                            "${isApproved ? '-' : ''} ${item['amount']} so'm",
                            style: TextStyle(
                              color: isApproved ? Colors.red : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 15
                            ),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
            ),
    );
  }

  Widget _buildCompanyBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          const Text("KORXONA UMUMIY BALANSI", style: TextStyle(color: Colors.white70, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Text(
            "${_companyBalance.toStringAsFixed(0)} so'm", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("Jami Tushum", _totalIncome, Colors.greenAccent),
              Container(width: 1, height: 40, color: Colors.white24),
              _statItem("Ish haqi to'landi", _totalPaid, Colors.orangeAccent),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Text(
          value.toStringAsFixed(0), 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ],
    );
  }
}