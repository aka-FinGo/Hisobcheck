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
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadUnapprovedLogs();
  }

  Future<void> _loadUnapprovedLogs() async {
    setState(() => _isLoading = true);
    try {
      // 1. Tasdiqlanmagan ishlarni olamiz
      // profiles:worker_id(...) -> Bu sintaksis juda muhim!
      final response = await _supabase
          .from('work_logs')
          .select('*, profiles:worker_id(full_name), orders:order_id(order_number, client_name)')
          .eq('is_approved', false)
          .order('created_at');

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Xatolik: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Yuklashda xato: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Bitta ishni tasdiqlash
  Future<void> _approveLog(int id) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('work_logs').update({
        'is_approved': true,
        'approved_by': userId,
        'approved_at': DateTime.now().toIso8601String(),
      }).eq('id', id);

      // Ro'yxatdan olib tashlaymiz (qayta yuklamasdan)
      setState(() {
        _logs.removeWhere((log) => log['id'] == id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tasdiqlandi!"), duration: Duration(milliseconds: 500)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  // Ishni rad etish (o'chirish)
  Future<void> _rejectLog(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rad etish"),
        content: const Text("Bu ishni o'chirib yuborasizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA, O'CHIRISH", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('work_logs').delete().eq('id', id);
      setState(() {
        _logs.removeWhere((log) => log['id'] == id);
      });
    }
  }

  // Hammasini tasdiqlash
  Future<void> _approveAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hammasini tasdiqlash"),
        content: Text("${_logs.length} ta ishni tasdiqlaysizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("HA, TASDIQLASH")
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final userId = _supabase.auth.currentUser!.id;
        final ids = _logs.map((e) => e['id']).toList();

        await _supabase.from('work_logs').update({
          'is_approved': true,
          'approved_by': userId,
          'approved_at': DateTime.now().toIso8601String(),
        }).in_('id', ids);

        setState(() {
          _logs.clear();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barchasi tasdiqlandi!"), backgroundColor: Colors.green));
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Tasdiqlash"),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              onPressed: _approveAll, 
              icon: const Icon(Icons.done_all, color: Colors.green),
              tooltip: "Hammasini tasdiqlash",
            )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _logs.isEmpty 
            ? const Center(child: Text("Tasdiqlanmagan ishlar yo'q", style: TextStyle(fontSize: 16, color: Colors.grey)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  // Null checklar bilan ma'lumot olish
                  final workerName = log['profiles']?['full_name'] ?? "Noma'lum usta";
                  final orderNum = log['orders']?['order_number'] ?? "?";
                  final clientName = log['orders']?['client_name'] ?? "";
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Text(workerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            "${log['total_sum']} so'm",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text("Zakaz: №$orderNum $clientName", style: const TextStyle(fontWeight: FontWeight.w500)),
                          Text("${log['task_type']} - ${log['area_m2']} m² (Tarif: ${log['rate']})"),
                          if (log['description'] != null && log['description'].toString().isNotEmpty)
                            Text("Izoh: ${log['description']}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                          const SizedBox(height: 5),
                          Text(
                            log['created_at'].toString().substring(0, 16),
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectLog(log['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle, color: Colors.green, size: 32),
                            onPressed: () => _approveLog(log['id']),
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