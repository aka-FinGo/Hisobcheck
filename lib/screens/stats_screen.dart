import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/finance_stat_card.dart'; // Biz yaratgan moliya kartasi

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _touchedIndex = -1; // Grafikni bosganda kattalashishi uchun

  // Moliya
  double _totalIncome = 0;
  double _totalExpense = 0;
  double _netProfit = 0;

  // Zakazlar soni
  int _completedOrders = 0;
  int _activeOrders = 0;
  int _canceledOrders = 0;

  // Top Xodimlar
  List<Map<String, dynamic>> _topWorkers = [];

  // Sana
  final String _currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());

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
        income += (o['total_price'] ?? 0).toDouble();
        String status = o['status'] ?? 'pending';
        
        if (status == 'completed') completed++;
        else if (status == 'canceled') canceled++;
        else active++;
      }

      // 2. XARAJATLAR (Tasdiqlangan to'lovlar)
      final withdrawals = await _supabase.from('withdrawals').select('amount').eq('status', 'approved');
      double expense = 0;
      for (var w in withdrawals) expense += (w['amount'] ?? 0).toDouble();

      // 3. TOP XODIMLAR (Eng ko'p ish bajarganlar)
      final workersStats = await _supabase
          .from('work_logs')
          .select('worker_id, total_sum, profiles(full_name)');
      
      // Ma'lumotlarni jamlash
      Map<String, dynamic> workerMap = {};
      for (var log in workersStats) {
        String uid = log['worker_id'];
        String name = log['profiles']?['full_name'] ?? "Noma'lum";
        double sum = (log['total_sum'] ?? 0).toDouble();

        if (workerMap.containsKey(uid)) {
          workerMap[uid]['sum'] += sum;
        } else {
          workerMap[uid] = {'name': name, 'sum': sum};
        }
      }

      // Ro'yxatga aylantirish va saralash (Eng ko'p pul ishlaganlar tepada)
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
          _topWorkers = sortedWorkers.take(5).toList(); // Faqat top 5 ta
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Statistika xatosi: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Och kulrang fon
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
                // SANA
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

                // 1. MOLIYA KARTALARI
                Row(
                  children: [
                    FinanceStatCard(
                      title: "Jami Kirim",
                      amount: _totalIncome,
                      color: const Color(0xFF00C853), // Yashil
                      icon: Icons.arrow_downward,
                    ),
                    const SizedBox(width: 15),
                    FinanceStatCard(
                      title: "Xarajatlar",
                      amount: _totalExpense,
                      color: const Color(0xFFFF3D00), // Qizil
                      icon: Icons.arrow_upward,
                      isExpense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. SOF FOYDA (KATTA KO'K KARTA)
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

                // 3. GRAFIK (PIE CHART)
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
                        child: PieChart(
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
                      // Legend (Tushuntirish)
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

                // 4. TOP XODIMLAR RO'YXATI
                _topWorkers.isEmpty 
                  ? const Center(child: Text("Hozircha ma'lumot yo'q"))
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
                                backgroundColor: i == 0 ? const Color(0xFFFFD700) : (i == 1 ? Colors.grey.shade300 : const Color(0xFFCD7F32)), // Oltin, Kumush, Bronza
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

  // GRAFIK BO'LAKLARI (Nol bo'lganda himoyalangan versiya)
  List<PieChartSectionData> _showingSections() {
    // 🔴 AGAR BAZADA ZAKAZ UUMUMAN YO'Q BO'LSA:
    if (_activeOrders == 0 && _completedOrders == 0 && _canceledOrders == 0) {
      return [
        PieChartSectionData(
          color: Colors.grey.shade300,
          value: 1,
          title: '0',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
        )
      ];
    }

    // AGAR ZAKAZLAR BO'LSA:
    return List.generate(3, (i) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;
      final widgetSize = isTouched ? 55.0 : 40.0;

      switch (i) {
        case 0:
          return PieChartSectionData(
            color: Colors.blue,
            value: _activeOrders.toDouble(),
            title: '$_activeOrders',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _activeOrders > 0 ? _Badge(Icons.timelapse, size: widgetSize, borderColor: Colors.blue) : null,
            badgePositionPercentageOffset: .98,
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFF00C853),
            value: _completedOrders.toDouble(),
            title: '$_completedOrders',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _completedOrders > 0 ? _Badge(Icons.check_circle, size: widgetSize, borderColor: const Color(0xFF00C853)) : null,
            badgePositionPercentageOffset: .98,
          );
        case 2:
          return PieChartSectionData(
            color: const Color(0xFFFF3D00),
            value: _canceledOrders.toDouble(),
            title: '$_canceledOrders',
            radius: radius,
            titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: _canceledOrders > 0 ? _Badge(Icons.cancel, size: widgetSize, borderColor: const Color(0xFFFF3D00)) : null,
            badgePositionPercentageOffset: .98,
          );
        default:
          throw Error();
      }
    });
  }
}

// Yordamchi Badge (Grafik ustidagi ikonka)
class _Badge extends StatelessWidget {
  const _Badge(this.icon, {required this.size, required this.borderColor});
  final IconData icon;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 3)],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(child: Icon(icon, color: borderColor, size: size * 0.6)),
    );
  }
}

// Yordamchi Legend (Pastdagi yozuvlar)
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
