import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddWithdrawalScreen extends StatefulWidget {
  const AddWithdrawalScreen({super.key});

  @override
  State<AddWithdrawalScreen> createState() => _AddWithdrawalScreenState();
}

class _AddWithdrawalScreenState extends State<AddWithdrawalScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  String? _selectedUserId;
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final data = await _supabase.from('profiles').select();
    setState(() => _users = data);
  }

  Future<void> _submit() async {
    if (_selectedUserId == null || _amountCtrl.text.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      await _supabase.from('withdrawals').insert({
        'worker_id': _selectedUserId,
        'amount': double.parse(_amountCtrl.text),
        'description': _descCtrl.text.isEmpty ? 'Avans' : _descCtrl.text,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pul muvaffaqiyatli berildi!")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pul Berish (Avans/Oylik)")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: "Xodimni tanlang", border: OutlineInputBorder()),
              items: _users.map((u) => DropdownMenuItem(
                value: u['id'].toString(),
                child: Text(u['full_name'] ?? 'Noma\'lum'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedUserId = v),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: "Summa (so'm)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            _isLoading 
            ? const CircularProgressIndicator()
            : ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("TASDIQLASH VA BERISH"),
            )
          ],
        ),
      ),
    );
  }
}
