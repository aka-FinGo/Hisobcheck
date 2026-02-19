import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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

  // Ro'yxatlar
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _workers = []; // Admin tanlashi uchun xodimlar

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

      // 2. KUTILAYOTGAN SO'ROVLAR (worker_id orqali profillarga ulanamiz)
      final requests = await _supabase
          .from('withdrawals')
          .select('id, amount, created_at, profiles!withdrawals_worker_id_fkey(full_name, phone)')
          .eq('status', 'pending')
          .order('created_at');

      // 3. TARIX
      final historyRes = await _supabase
          .from('withdrawals')
          .select('id, amount, status, created_at, profiles!withdrawals_worker_id_fkey(full_name)')
          .neq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(20);

      // 4. XODIMLAR RO'YXATI (Admin qo'lda pul berishi uchun)
      final workersRes = await _supabase.from('profiles').select('id, full_name, role').neq('role', 'admin');

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalPaid = paid;
          _companyBalance = income - paid;
          _pendingRequests = List<Map<String, dynamic>>.from(requests);
          _history = List<Map<String, dynamic>>.from(historyRes);
          _workers = List<Map<String, dynamic>>.from(workersRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Moliya yuklashda xato: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // --- XODIM SO'RAGAN PULNI TASDIQLASH/RAD ETISH ---
  void _processRequest(int id, bool approve) async {
    try {
      await _supabase.from('withdrawals').update({
        'status': approve ? 'approved' : 'canceled'
      }).eq('id', id);
      
      _loadFinanceData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? "To'lov tasdiqlandi!" : "So'rov rad etildi!"),
        backgroundColor: approve ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
    }
  }

  // --- ADMIN QO'LDA PUL BERISHI (YANGI FUNKSIYA) ---
  void _showGiveMoneyDialog() {
    dynamic selectedWorkerId;
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text("Xodimga Pul Berish"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(labelText: "Xodimni tanlang", border: OutlineInputBorder()),
                items: _workers.map((w) => DropdownMenuItem<dynamic>(
                  value: w['id'], 
                  child: Text(w['full_name'] ?? "Noma'lum")
                )).toList(),
                onChanged: (v) => setModalState(() => selectedWorkerId = v),
              ),
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
                final amount = double.tryParse(amountController.text) ?? 0;
                if (selectedWorkerId == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xodimni tanlang va summani kiriting!")));
                  return;
                }

                try {
                  // Admin qo'lda bergan pul to'g'ridan-to'g'ri "approved" (tasdiqlangan) bo'lib tushadi
                  await _supabase.from('withdrawals').insert({
                    'worker_id': selectedWorkerId,
                    'amount': amount,
                    'status': 'approved'
                  });

                  if (mounted) {
                    Navigator.pop(ctx);
                    _loadFinanceData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To'lov saqlandi!"), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
                }
              },
              child: const Text("PUL BERISH"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,###");

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Moliya va Kassa", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      
      // YANGI TUGMA: ADMIN QO'LDA PUL YAZISHI UCHUN
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGiveMoneyDialog,
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.payments, color: Colors.white),
        label: const Text("PUL BERISH", style: TextStyle(color: Colors.white)),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. KASSA KARTASI
                  _buildCompanyBalanceCard(formatter),
                  const SizedBox(height: 25),

                  // 2. KUTILAYOTGAN SO'ROVLAR
                  const Text("Kutilayotgan so'rovlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  _pendingRequests.isEmpty
                      ? const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Yangi so'rovlar yo'q", style: TextStyle(color: Colors.grey)))))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pendingRequests.length,
                          itemBuilder: (ctx, i) {
                            final req = _pendingRequests[i];
                            final profile = req['profiles'];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.orange.shade100,
                                  child: const Icon(Icons.timer, color: Colors.orange),
                                ),
                                title: Text(profile?['full_name'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${formatter.format(req['amount']).replaceAll(',', ' ')} so'm"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                                      onPressed: () => _processRequest(req['id'], false),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                      onPressed: () => _processRequest(req['id'], true),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                  const SizedBox(height: 25),
                  const Text("To'lovlar Tarixi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 10),
                  
                  // 3. TARIX
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _history.length,
                    itemBuilder: (ctx, i) {
                      final item = _history[i];
                      final profile = item['profiles'];
                      bool isApproved = item['status'] == 'approved';
                      
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isApproved ? Icons.done_all : Icons.block, 
                            color: isApproved ? Colors.green : Colors.red
                          ),
                          title: Text(profile?['full_name'] ?? "Noma'lum"),
                          subtitle: Text(item['created_at'].toString().split('T')[0]),
                          trailing: Text(
                            "${isApproved ? '-' : ''} ${formatter.format(item['amount']).replaceAll(',', ' ')} so'm",
                            style: TextStyle(
                              color: isApproved ? Colors.red.shade700 : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 15
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 60), // FAB tugma pastni to'sib qo'ymasligi uchun
                ],
              ),
            ),
    );
  }

  Widget _buildCompanyBalanceCard(NumberFormat formatter) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          const Text("KORXONA UMUMIY BALANSI", style: TextStyle(color: Colors.white70, letterSpacing: 1.5, fontSize: 12)),
          const SizedBox(height: 10),
          Text(
            "${formatter.format(_companyBalance).replaceAll(',', ' ')} so'm", 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("Jami Tushum", _totalIncome, Colors.greenAccent, formatter),
              Container(width: 1, height: 40, color: Colors.white24),
              _statItem("Ish haqi to'landi", _totalPaid, Colors.orangeAccent, formatter),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, double value, Color color, NumberFormat formatter) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          formatter.format(value).replaceAll(',', ' '), 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)
        ),
      ],
    );
  }
}
