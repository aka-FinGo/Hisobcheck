import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/finance_stat_card.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _touchedIndex = -1;

  // Moliya
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netProfit = 0;

  // Zakazlar
  int _completedOrders = 0;
  int _activeOrders = 0;
  int _canceledOrders = 0;

  // Top Xodimlar
  List<Map<String, dynamic>> _topWorkers = [];

  // Sana (Lokalizatsiya xatosi bermasligi uchun oddiy format)
  final String _currentMonth = DateFormat('MMMM, yyyy').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // 1. ZAKAZLAR VA KIRIM
      final orders = await _supabase.from('orders').select('status, total_price');
      
      double income = 0;
      int completed = 0;
      int active = 0;
      int canceled = 0;

      for (var o in orders) {
        income += double.tryParse(o['total_price'].toString()) ?? 0.0;
        String status = o['status'] ?? 'pending';
        
        if (status == 'completed') {
          completed++;
        } else if (status == 'canceled') {
          canceled++;
        } else {
          active++;
        }
      }

      // 2. XARAJATLAR
      final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
      double expense = 0;
      for (var w in withdrawals) {
        expense += double.tryParse(w['amount'].toString()) ?? 0.0;
      }

      // 3. TOP XODIMLAR
      final workersStats = await _supabase.from('work_logs').select('worker_id, total_sum, profiles(full_name)');
      
      Map<String, dynamic> workerMap = {};
      for (var log in workersStats) {
        String uid = log['worker_id'].toString();
        String name = "Noma'lum";
        
        if (log['profiles'] != null && log['profiles']['full_name'] != null) {
          name = log['profiles']['full_name'].toString();
        }
        
        double sum = double.tryParse(log['total_sum'].toString()) ?? 0.0;

        if (workerMap.containsKey(uid)) {
          workerMap[uid]['sum'] += sum;
        } else {
          workerMap[uid] = {'name': name, 'sum': sum};
        }
      }

      List<Map<String, dynamic>> sortedWorkers = workerMap.values.toList().cast<Map<String, dynamic>>();
      sortedWorkers.sort((a, b) => b['sum'].compareTo(a['sum']));

      if (mounted) {
        setState(() {
          _totalIncome = income;
          _totalExpense = expense;
          _netProfit = income - expense;
          _completedOrders = completed;
          _activeOrders = active;
          _canceledOrders = canceled;
          _topWorkers = sortedWorkers.take(5).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Statistika yuklash xatosi: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Hisobotlar", style: TextStyle(color: Color(0xFF2D3142), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2D3142)),
        actions: [
          IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(_currentMonth, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),

                // MOLIYA KARTALARI
                Row(
                  children: [
                    FinanceStatCard(
                      title: "Jami Kirim",
                      amount: _totalIncome,
                      color: const Color(0xFF00C853),
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(width: 15),
                    FinanceStatCard(
                      title: "Xarajatlar",
                      amount: _totalExpense,
                      color: const Color(0xFFFF3D00),
                      icon: Icons.arrow_upward,
                      isExpense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // SOF FOYDA
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E5BFF), Color(0xFF1441E6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF2E5BFF).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text("SOF FOYDA (KASSA)", style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
                      const SizedBox(height: 8),
                      Text(
                        "${NumberFormat("#,###").format(_netProfit).replaceAll(',', ' ')} so'm",
                        style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text("Zakazlar Statistikasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 15),

                // GRAFIK (QOTIB QOLMASLIGI UCHUN HIMOYALANGAN)
                Container(
                  height: 320,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: (_activeOrders == 0 && _completedOrders == 0 && _canceledOrders == 0)
                            ? const Center(child: Text("Hozircha zakazlar yo'q", style: TextStyle(color: Colors.grey)))
                            : PieChart(
                                PieChartData(
                                  pieTouchData: PieTouchData(
                                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                      setState(() {
                                        if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                                          _touchedIndex = -1;
                                          return;
                                        }
                                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                      });
                                    },
                                  ),
                                  borderData: FlBorderData(show: false),
                                  sectionsSpace: 2,
                                  centerSpaceRadius: 40,
                                  sections: _showingSections(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Indicator(color: Colors.blue, text: 'Jarayonda'),
                          _Indicator(color: Colors.green, text: 'Bitgan'),
                          _Indicator(color: Colors.red, text: 'Bekor'),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text("Top Xodimlar (Reyting)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3142))),
                const SizedBox(height: 15),

                // TOP XODIMLAR
                _topWorkers.isEmpty 
                  ? const Center(child: Text("Hozircha ma'lumot yo'q", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topWorkers.length,
                      itemBuilder: (ctx, i) {
                        final w = _topWorkers[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)],
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: i == 0 ? const Color(0xFFFFD700) : (i == 1 ? Colors.grey.shade300 : const Color(0xFFCD7F32)),
                                child: Text("${i + 1}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(w['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text("Ish haqi: ${NumberFormat("#,###").format(w['sum']).replaceAll(',', ' ')} so'm", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              ),
                              if (i == 0) const Icon(Icons.emoji_events, color: Color(0xFFFFD700)),
                            ],
                          ),
                        );
                      },
                    ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  List<PieChartSectionData> _showingSections() {
    return List.generate(3, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: Colors.blue,
            value: _activeOrders.toDouble(),
            title: _activeOrders > 0 ? '$_activeOrders' : '',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFF00C853),
            value: _completedOrders.toDouble(),
            title: _completedOrders > 0 ? '$_completedOrders' : '',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
          );
        case 2:
          return PieChartSectionData(
            color: const Color(0xFFFF3D00),
            value: _canceledOrders.toDouble(),
            title: _canceledOrders > 0 ? '$_canceledOrders' : '',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
          );
        default:
          throw Error();
      }
    });
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;

  const _Indicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }
}
