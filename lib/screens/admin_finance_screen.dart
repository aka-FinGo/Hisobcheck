import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  double _totalIncome = 0;
  double _totalPaid = 0;
  double _monthIncome = 0;
  double _monthPaid = 0;
  double _companyBalance = 0;

  // Ro'yxatlar
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _workers = [];
  Map<String, double> _workerSalaries = {}; // Aggregated totals per month

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
      final incomeList = List<Map<String, dynamic>>.from(orders);
      final paidList = List<Map<String, dynamic>>.from(approvedWithdrawals);
      
      for (var o in incomeList) income += (o['total_price'] ?? 0).toDouble();
      for (var w in paidList) paid += (w['amount'] ?? 0).toDouble();

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

      _applyFilters(orders, approvedWithdrawals, requests, historyRes, workersRes);
    } catch (e) {
      debugPrint("Moliya yuklashda xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters(List incomeList, List paidList, List requests, List history, List workers) {
    if (mounted) {
      setState(() {
        _totalIncome = 0;
        _totalPaid = 0;
        _monthIncome = 0;
        _monthPaid = 0;

        for (var o in incomeList) {
          final amt = (o['total_price'] ?? 0).toDouble();
          _totalIncome += amt;
          // Filter by month for monthIncome
          if (o['created_at'] != null) {
             final date = DateTime.parse(o['created_at']);
             if (date.year == _selectedMonth.year && date.month == _selectedMonth.month) _monthIncome += amt;
          }
        }

        for (var w in paidList) {
          final amt = (w['amount'] ?? 0).toDouble();
          _totalPaid += amt;
          if (w['created_at'] != null) {
             final date = DateTime.parse(w['created_at']);
             if (date.year == _selectedMonth.year && date.month == _selectedMonth.month) _monthPaid += amt;
          }
        }

        _companyBalance = _totalIncome - _totalPaid;
        
        _pendingRequests = List<Map<String, dynamic>>.from(requests).where((r) {
          final date = DateTime.parse(r['created_at']);
          return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
        }).toList();
        _history = List<Map<String, dynamic>>.from(history).where((h) {
          final date = DateTime.parse(h['created_at']);
          return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
        }).toList();

        // Calculate per-worker totals for selected month
        _workerSalaries = {};
        for (var item in _history) {
          if (item['status'] == 'approved') {
            final workerName = item['profiles']?['full_name'] ?? "Noma'lum";
            final amt = (item['amount'] ?? 0).toDouble();
            _workerSalaries[workerName] = (_workerSalaries[workerName] ?? 0) + amt;
          }
        }

        _workers = List<Map<String, dynamic>>.from(workers);
        _isLoading = false;
      });
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
    final rateController = TextEditingController(text: "12900");
    bool isUsd = false;

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
                decoration: InputDecoration(
                  labelText: "Summa", 
                  border: const OutlineInputBorder(), 
                  suffixText: isUsd ? "USD" : "so'm",
                  prefixIcon: IconButton(
                    icon: Icon(isUsd ? Icons.attach_money : Icons.money),
                    onPressed: () => setModalState(() => isUsd = !isUsd),
                  ),
                ),
              ),
              if (isUsd) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: rateController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Dollar kursi", border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_exchange)),
                ),
              ],
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
                  final rate = double.tryParse(rateController.text) ?? 12900;
                  final finalAmount = isUsd ? amount * rate : amount;
                  
                  // Admin qo'lda bergan pul to'g'ridan-to'g'ri "approved" (tasdiqlangan) bo'lib tushadi
                  await _supabase.from('withdrawals').insert({
                    'worker_id': selectedWorkerId,
                    'amount': finalAmount,
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
    final theme = Theme.of(context);
    final statsTheme = theme.extension<StatsTheme>()!;
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;
    final formatter = NumberFormat("#,###");

    return Scaffold(
      backgroundColor: isGlass ? Colors.transparent : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("MOLIYAVIY NAZORAT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5, fontStyle: FontStyle.italic)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGiveMoneyDialog,
        backgroundColor: statsTheme.income,
        icon: const Icon(Icons.payments_rounded, color: Colors.white),
        label: const Text("PUL BERISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildMonthSelector(statsTheme),
                  const SizedBox(height: 20),
                  _buildCompanyBalanceCard(formatter, statsTheme),
                  const SizedBox(height: 30),
                  _buildSectionHeader("Kutilayotgan so'rovlar", Icons.timer_outlined, statsTheme.pending),
                  const SizedBox(height: 15),
                  _buildPendingList(formatter, statsTheme),
                  const SizedBox(height: 30),
                  _buildSectionHeader("Xodimlar Hisoboti", Icons.people_outline_rounded, statsTheme.income),
                  const SizedBox(height: 15),
                  _buildWorkerSalariesList(formatter, statsTheme),
                  const SizedBox(height: 30),
                  _buildSectionHeader("To'lovlar Tarixi", Icons.history_rounded, statsTheme.income),
                  const SizedBox(height: 15),
                  _buildHistoryList(formatter, statsTheme),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildMonthSelector(StatsTheme statsTheme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(6, (i) {
          final date = DateTime.now().subtract(Duration(days: 30 * i));
          final isSelected = date.year == _selectedMonth.year && date.month == _selectedMonth.month;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(DateFormat('MMMM').format(date).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isSelected ? Colors.white : statsTheme.textSecondary)),
              selected: isSelected,
              onSelected: (v) {
                if (v) {
                  setState(() {
                    _selectedMonth = date;
                    _loadFinanceData();
                  });
                }
              },
              selectedColor: statsTheme.income,
              backgroundColor: statsTheme.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        }).reversed.toList(),
      ),
    );
  }

  Widget _buildCompanyBalanceCard(NumberFormat formatter, StatsTheme statsTheme) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: statsTheme.cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: statsTheme.income.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          const Text("KORXONA UMUMIY BALANSI", style: TextStyle(color: Colors.grey, letterSpacing: 1.5, fontSize: 10, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            "${formatter.format(_companyBalance)} UZS", 
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("${DateFormat('MMMM').format(_selectedMonth)} kirimi", _monthIncome, statsTheme.income, formatter),
              Container(width: 1, height: 35, color: Colors.white.withOpacity(0.1)),
              _statItem("${DateFormat('MMMM').format(_selectedMonth)} chiqimi", _monthPaid, statsTheme.expense, formatter),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, double value, Color color, NumberFormat formatter) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(
          formatter.format(value), 
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)
        ),
      ],
    );
  }

  Widget _buildPendingList(NumberFormat formatter, StatsTheme statsTheme) {
    if (_pendingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: statsTheme.cardColor, borderRadius: BorderRadius.circular(25)),
        child: const Center(child: Text("Yangi so'rovlar yo'q", style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }
    return Column(
      children: _pendingRequests.map((req) {
        final profile = req['profiles'];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: statsTheme.cardColor,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.03)),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: statsTheme.pending.withOpacity(0.1), child: Icon(Icons.timer_outlined, color: statsTheme.pending, size: 20)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?['full_name'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text("${formatter.format(req['amount'])} UZS", style: TextStyle(color: statsTheme.pending, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent), onPressed: () => _processRequest(req['id'], false)),
                  IconButton(icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent), onPressed: () => _processRequest(req['id'], true)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWorkerSalariesList(NumberFormat formatter, StatsTheme statsTheme) {
    if (_workerSalaries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: statsTheme.cardColor, borderRadius: BorderRadius.circular(25)),
        child: const Center(child: Text("Ushbu oyda hali to'lovlar qilinmagan", style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }
    return Column(
      children: _workerSalaries.entries.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: statsTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.02)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   CircleAvatar(
                     radius: 15,
                     backgroundColor: statsTheme.income.withOpacity(0.1),
                     child: Text(e.key[0].toUpperCase(), style: TextStyle(color: statsTheme.income, fontSize: 12, fontWeight: FontWeight.bold)),
                   ),
                   const SizedBox(width: 12),
                   Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Text(
                "${formatter.format(e.value)} UZS",
                style: TextStyle(color: statsTheme.income, fontWeight: FontWeight.w900, fontSize: 13),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryList(NumberFormat formatter, StatsTheme statsTheme) {
    if (_history.isEmpty) {
      return const Center(child: Text("Hozircha ma'lumot yo'q", style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: _history.map((item) {
        final profile = item['profiles'];
        final isApproved = item['status'] == 'approved';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: statsTheme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.02)),
          ),
          child: Row(
            children: [
              Icon(isApproved ? Icons.done_all_rounded : Icons.block_rounded, color: isApproved ? statsTheme.income : statsTheme.textSecondary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile?['full_name'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(DateFormat('dd MMM, yyyy').format(DateTime.parse(item['created_at'])), style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
              ),
              Text(
                "${isApproved ? '-' : ''} ${formatter.format(item['amount'])}",
                style: TextStyle(color: isApproved ? statsTheme.expense : Colors.grey, fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
