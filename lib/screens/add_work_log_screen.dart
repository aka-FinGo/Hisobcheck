import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});

  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

// Tab tizimi ishlashi uchun SingleTickerProviderStateMixin qo'shiladi
class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<dynamic> _workLogs = [];
  List<dynamic> _withdrawals = [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllPending();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPending() async {
    setState(() => _isLoading = true);
    try {
      // 1. Tasdiqlanmagan ISHLAR (worker va order degan laqab bilan tortamiz xato bermasligi uchun)
      final logsRes = await _supabase
          .from('work_logs')
          .select('*, worker:profiles!work_logs_worker_id_fkey(full_name), order:orders(order_number, project_name)')
          .eq('is_approved', false)
          .order('created_at', ascending: true);

      // 2. Kutilayotgan AVANSLAR
      final avansRes = await _supabase
          .from('withdrawals')
          .select('*, worker:profiles(full_name)')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _workLogs = logsRes;
          _withdrawals = avansRes;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Yuklashda xato: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== ISHLARNI BOSHQARISH ====================
  Future<void> _approveLog(int id) async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      await _supabase.from('work_logs').update({
        'is_approved': true,
        'approved_by': myId,
        'approved_at': DateTime.now().toIso8601String()
      }).eq('id', id);
      
      _loadAllPending();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish tasdiqlandi va hisobga o'tdi!"), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectLog(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Rad etish"),
        content: const Text("Ushbu ish xato kiritilganmi? Uni butunlay o'chirib tashlaysizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Bekor")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text("Ha, o'chirish", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('work_logs').delete().eq('id', id);
        _loadAllPending();
      } catch(e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ==================== AVANSLARNI BOSHQARISH ====================
  Future<void> _approveAvans(int id) async {
    try {
      await _supabase.from('withdrawals').update({'status': 'approved'}).eq('id', id);
      _loadAllPending();
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Avans tasdiqlandi!"), backgroundColor: Colors.green));
    } catch(e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectAvans(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Rad etish"),
        content: const Text("Avans so'rovini bekor qilasizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Yo'q")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text("Ha, bekor qilish", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('withdrawals').delete().eq('id', id);
        _loadAllPending();
      } catch(e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // ==================== UI QISMI ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rahbar Tasdig'i", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          indicatorWeight: 3,
          tabs: [
            Tab(text: "Ishlar (${_workLogs.length})", icon: const Icon(Icons.assignment_turned_in)),
            Tab(text: "Avanslar (${_withdrawals.length})", icon: const Icon(Icons.money_off)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWorkLogsTab(),
                _buildWithdrawalsTab(),
              ],
            ),
    );
  }

  // 1-TAB: ISHLAR
  Widget _buildWorkLogsTab() {
    if (_workLogs.isEmpty) {
      return const Center(child: Text("Tasdiqlash uchun ishlar yo'q", style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _workLogs.length,
      itemBuilder: (context, index) {
        final log = _workLogs[index];
        final workerName = log['worker']?['full_name'] ?? "Noma'lum xodim";
        final orderNum = log['order']?['order_number'] ?? "Noma'lum zakaz";
        final projectName = log['order']?['project_name'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade200, width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(workerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
                    Text(orderNum, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  ],
                ),
                const Divider(),
                Text("Vazifa: ${log['task_type']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                if (projectName.isNotEmpty) Text("Loyiha: $projectName", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Miqdor: ${log['area_m2']}"),
                    Text("Stavka: ${NumberFormat("#,###").format(log['rate'])} so'm", style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 5),
                Text("Jami hisoblangan: ${NumberFormat("#,###").format(log['total_sum'])} so'm", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                if (log['description'] != null && log['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text("Izoh: ${log['description']}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.close),
                      label: const Text("Rad etish"),
                      onPressed: () => _rejectLog(log['id']),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.check),
                      label: const Text("Tasdiqlash"),
                      onPressed: () => _approveLog(log['id']),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // 2-TAB: AVANSLAR
  Widget _buildWithdrawalsTab() {
    if (_withdrawals.isEmpty) {
      return const Center(child: Text("So'ralgan avanslar yo'q", style: TextStyle(color: Colors.grey, fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _withdrawals.length,
      itemBuilder: (context, index) {
        final avans = _withdrawals[index];
        final workerName = avans['worker']?['full_name'] ?? "Noma'lum xodim";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.blue.shade200, width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(workerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Icon(Icons.money_off, color: Colors.orange),
                  ],
                ),
                const Divider(),
                Text("So'ralgan summa: ${NumberFormat("#,###").format(avans['amount'])} so'm", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                if (avans['description'] != null && avans['description'].toString().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text("Sabab/Izoh: ${avans['description']}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                      icon: const Icon(Icons.close),
                      label: const Text("Rad etish"),
                      onPressed: () => _rejectAvans(avans['id']),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      icon: const Icon(Icons.check),
                      label: const Text("Tasdiqlash"),
                      onPressed: () => _approveAvans(avans['id']),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
