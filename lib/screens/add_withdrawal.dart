import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddWithdrawalScreen extends StatefulWidget {
  const AddWithdrawalScreen({super.key});

  @override
  State<AddWithdrawalScreen> createState() => _AddWithdrawalScreenState();
}

class _AddWithdrawalScreenState extends State<AddWithdrawalScreen> {
  final _supabase = Supabase.instance.client;
  String? _selectedWorker;
  final _amount = TextEditingController();
  List<dynamic> _workers = [];

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    final data = await _supabase.from('profiles').select().eq('role', 'worker');
    setState(() => _workers = data);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pul berish")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              items: _workers.map((w) => DropdownMenuItem(value: w['id'].toString(), child: Text(w['full_name']))).toList(),
              onChanged: (v) => _selectedWorker = v,
              decoration: const InputDecoration(labelText: "Ishchini tanlang"),
            ),
            TextField(controller: _amount, decoration: const InputDecoration(labelText: "Summa"), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (_selectedWorker == null || _amount.text.isEmpty) return;
                await _supabase.from('withdrawals').insert({
                  'worker_id': _selectedWorker,
                  'amount': double.parse(_amount.text),
                  'created_by_admin': true,
                });
                Navigator.pop(context);
              }, 
              child: const Text("SAQLASH")
            )
          ],
        ),
      ),
    );
  }
}
