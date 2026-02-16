import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  double _totalOrdersIncome = 0; // Mijozlardan tushgan jami pul
  double _totalWorkerDebts = 0;  // Ishchilardan jami qarzimiz
  double _totalPaidToWorkers = 0; // Ishchilarga berilgan jami pul

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      // 1. Zakazlar summasini olish
      final orders = await _supabase.from('orders').select('total_price');
      // 2. Ishchilar ishlab qo'ygan (tasdiqlangan) jami summa
      final workLogs = await _supabase.from('work_logs').select('total_sum').eq('is_approved', true);
      // 3. Ishchilarga berib bo'lingan jami pul
      final withdrawals = await _supabase.from('withdrawals').select('amount');

      double ordersSum = 0;
      for (var o in orders) ordersSum += (o['total_price'] ?? 0).toDouble();

      double workSum = 0;
      for (var w in workLogs) workSum += (w['total_sum'] ?? 0).toDouble();

      double paidSum = 0;
      for (var p in withdrawals) paidSum += (p['amount'] ?? 0).toDouble();

      setState(() {
        _totalOrdersIncome = ordersSum;
        _totalWorkerDebts = workSum - paidSum; // Ishlangan pul minus berilgan pul
        _totalPaidToWorkers = paidSum;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sex Statistikasi"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadStats,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statCard("Umumiy Tushum (Orders)", _totalOrdersIncome, Colors.blue),
                const SizedBox(height: 12),
                _statCard("Ishchilarga To'langan", _totalPaidToWorkers, Colors.green),
                const SizedBox(height: 12),
                _statCard("Ishchilardan Qarzimiz", _totalWorkerDebts, Colors.red),
                const SizedBox(height: 25),
                const Divider(),
                const Text("Tahlil:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text(
                  "Sexning sof foydasi (taxminan): ${(_totalOrdersIncome - _totalPaidToWorkers - _totalWorkerDebts).toStringAsFixed(0)} so'm",
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),
    );
  }

  Widget _statCard(String title, double amount, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
        trailing: Text(
          "${amount.toStringAsFixed(0)} so'm",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }
}
