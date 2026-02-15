import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _balance = 0;
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Ishxonadan olingan pullarni "Kirim" sifatida hisoblaymiz
      final withdrawals = await _supabase.from('withdrawals').select().eq('worker_id', userId);
      
      // 2. Shaxsiy xarajatlarni olamiz
      final personal = await _supabase.from('personal_wallet').select().eq('user_id', userId).order('created_at');

      double totalIn = 0;
      for (var w in withdrawals) totalIn += (w['amount'] ?? 0).toDouble();

      double totalPersonal = 0;
      for (var p in personal) {
        if (p['type'] == 'income') {
          totalIn += (p['amount'] ?? 0).toDouble();
        } else {
          totalPersonal += (p['amount'] ?? 0).toDouble();
        }
      }

      setState(() {
        _transactions = personal;
        _balance = totalIn - totalPersonal;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _addExpenseDialog() {
    final amountController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Xarajat qo'shish"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountController, decoration: const InputDecoration(labelText: "Summa"), keyboardType: TextInputType.number),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Nima uchun?")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              if (amountController.text.isEmpty) return;
              await _supabase.from('personal_wallet').insert({
                'user_id': _supabase.auth.currentUser!.id,
                'type': 'expense',
                'amount': double.parse(amountController.text),
                'description': descController.text,
              });
              Navigator.pop(context);
              _loadWalletData();
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mening Hamyonim")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpenseDialog,
        backgroundColor: Colors.blue.shade900,
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  color: Colors.blue.shade900,
                  child: Column(
                    children: [
                      const Text("Hamyondagi sof qoldiq:", style: TextStyle(color: Colors.white70)),
                      Text("${_balance.toStringAsFixed(0)} so'm", 
                           style: const TextStyle(color: Colors.white, fontSize: 35, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final item = _transactions[index];
                      return ListTile(
                        leading: const Icon(Icons.payment, color: Colors.red),
                        title: Text(item['description'] ?? "Xarajat"),
                        subtitle: Text(DateFormat('dd.MM.yyyy').format(DateTime.parse(item['created_at']))),
                        trailing: Text("-${item['amount']} so'm", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
