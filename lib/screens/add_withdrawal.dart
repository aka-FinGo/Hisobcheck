import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddWithdrawalScreen extends StatefulWidget {
  const AddWithdrawalScreen({super.key});

  @override
  State<AddWithdrawalScreen> createState() => _AddWithdrawalScreenState();
}

class _AddWithdrawalScreenState extends State<AddWithdrawalScreen> {
  final _supabase = Supabase.instance.client;
  String? _selectedWorkerId;
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  List<dynamic> _workers = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    final data = await _supabase.from('profiles').select().eq('role', 'worker');
    setState(() => _workers = data);
  }

  Future<void> _saveWithdrawal() async {
    if (_selectedWorkerId == null || _amountController.text.isEmpty) return;

    setState(() => _isSaving = true);
    final amount = double.parse(_amountController.text);

    // 1. Withdrawals jadvaliga yozish
    await _supabase.from('withdrawals').insert({
      'worker_id': _selectedWorkerId,
      'amount': amount,
      'description': _descController.text,
      'created_by_admin': true,
    });

    // 2. Ishxona kassasidan ayirish (Ixtiyoriy, agar kassa jadvalini ishlatsak)
    await _supabase.from('company_finance').insert({
      'type': 'expense',
      'amount': amount,
      'category': 'Ish haqi / Avans',
      'description': "Xodimga berildi: ${_descController.text}",
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To'lov saqlandi 💸")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pul berish (Avans)")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Xodimni tanlang", border: OutlineInputBorder()),
              items: _workers.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['full_name']))).toList(),
              onChanged: (v) => _selectedWorkerId = v,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: "Summa (so'm)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Izoh (masalan: Avans)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveWithdrawal,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55)),
              child: _isSaving ? const CircularProgressIndicator() : const Text("SAQLASH"),
            )
          ],
        ),
      ),
    );
  }
}
