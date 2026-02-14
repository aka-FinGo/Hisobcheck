import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _pendingLogs = [];

  @override
  void initState() {
    super.initState();
    _loadPendingLogs();
  }

  Future<void> _loadPendingLogs() async {
    setState(() => _isLoading = true);
    // Tasdiqlanmagan ishlarni ishchi nomi bilan birga olib kelamiz
    final data = await _supabase
        .from('work_logs')
        .select('*, profiles(full_name), orders(order_number)')
        .eq('is_approved', false)
        .order('created_at');

    setState(() {
      _pendingLogs = data;
      _isLoading = false;
    });
  }

  Future<void> _approveWork(int id) async {
    await _supabase.from('work_logs').update({'is_approved': true}).eq('id', id);
    _loadPendingLogs(); // Ro'yxatni yangilash
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish tasdiqlandi ✅")));
    }
  }

  Future<void> _deleteWork(int id) async {
    await _supabase.from('work_logs').delete().eq('id', id);
    _loadPendingLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tasdiqlash kutilmoqda")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingLogs.isEmpty
              ? const Center(child: Text("Hozircha yangi ishlar yo'q"))
              : ListView.builder(
                  itemCount: _pendingLogs.length,
                  itemBuilder: (context, index) {
                    final log = _pendingLogs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text("${log['profiles']['full_name']} - ${log['orders']['order_number']}"),
                        subtitle: Text("${log['task_type']}: ${log['area_m2']} m2 \nSumma: ${log['total_sum']} so'm"),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green),
                              onPressed: () => _approveWork(log['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              onPressed: () => _deleteWork(log['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
