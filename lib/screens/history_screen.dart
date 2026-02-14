import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Sana formatlash uchun (pubspec.yaml ga qo'shish kerak)

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Ishchi o'zining hamma ishlarini (tasdiqlangan va yo'q) ko'radi
      final data = await _supabase
          .from('work_logs')
          .select('*, orders(order_number)')
          .eq('worker_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _history = data;
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
        title: const Text("Ishlar Tarixi"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text("Hozircha tarix mavjud emas"))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    final bool isApproved = item['is_approved'] ?? false;
                    final DateTime createdAt = DateTime.parse(item['created_at']);
                    
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: isApproved ? Colors.green.shade100 : Colors.orange.shade100,
                          child: Icon(
                            isApproved ? Icons.check_circle : Icons.pending,
                            color: isApproved ? Colors.green : Colors.orange,
                          ),
                        ),
                        title: Text(
                          "${item['orders']['order_number']} - ${item['task_type']}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("${item['area_m2']} m² × ${item['rate']} so'm"),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm').format(createdAt),
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Text(
                          "${item['total_sum']} so'm",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isApproved ? Colors.blue.shade900 : Colors.black54,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
