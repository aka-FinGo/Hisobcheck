import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final data = await _supabase
        .from('work_logs')
        .select('*, profiles(full_name), orders(order_number)')
        .eq('is_approved', false);
    setState(() {
      _logs = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tasdiqlash")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (context, i) {
              final log = _logs[i];
              return Card(
                child: ListTile(
                  title: Text("${log['profiles']['full_name']} - ${log['orders']['order_number']}"),
                  subtitle: Text("${log['task_type']} - ${log['area_m2']} m2"),
                  trailing: IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      await _supabase.from('work_logs').update({'is_approved': true}).eq('id', log['id']);
                      _loadLogs();
                    },
                  ),
                ),
              );
            },
          ),
    );
  }
}
