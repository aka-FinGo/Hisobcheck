import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminApprovalsScreen extends StatefulWidget {
  const AdminApprovalsScreen({super.key});
  @override
  State<AdminApprovalsScreen> createState() => _AdminApprovalsScreenState();
}

class _AdminApprovalsScreenState extends State<AdminApprovalsScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = true;
  
  List<dynamic> _workLogs = [];
  List<dynamic> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllPending();
  }

  Future<void> _loadAllAllPending() async {
    setState(() => _isLoading = true);
    try {
      // 1. TASDIQLANMAGAN ISHLAR (worker nomi va order raqami bilan)
      final logsRes = await _supabase
          .from('work_logs')
          .select('*, profiles!work_logs_worker_id_fkey(full_name), orders(order_number, project_name)')
          .eq('is_approved', false)
          .order('created_at', ascending: true);

      // 2. KUTILAYOTGAN AVANSLAR (worker nomi bilan)
      final avansRes = await _supabase
          .from('withdrawals')
          .select('*, profiles!withdrawals_worker_id_fkey(full_name)')
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _workLogs = logsRes;
          _withdrawals = avansRes;
        });
      }
    } catch (e) {
      debugPrint("Yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ISHLARNI TASDIQLASH/RAD ETISH ---
  Future<void> _handleWork(int id, bool approve) async {
    try {
      if (approve) {
        await _supabase.from('work_logs').update({
          'is_approved': true,
          'approved_by': _supabase.auth.currentUser!.id,
          'approved_at': DateTime.now().toIso8601String()
        }).eq('id', id);
      } else {
        await _supabase.from('work_logs').delete().eq('id', id);
      }
      _loadAllAllPending();
    } catch (e) { _msg("Xato: $e"); }
  }

  // --- AVANSLARNI TASDIQLASH/RAD ETISH ---
  Future<void> _handleAvans(int id, bool approve) async {
    try {
      if (approve) {
        await _supabase.from('withdrawals').update({'status': 'approved'}).eq('id', id);
      } else {
        await _supabase.from('withdrawals').update({'status': 'rejected'}).eq('id', id);
      }
      _loadAllAllPending();
    } catch (e) { _msg("Xato: $e"); }
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));
@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tasdiqlashlar"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Ishlar (${_workLogs.length})"),
            Tab(text: "Avanslar (${_withdrawals.length})"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
            controller: _tabController,
            children: [
              _buildWorkTab(theme, isGlass),
              _buildAvansTab(theme, isGlass),
            ],
          ),
    );
  }

  Widget _buildWorkTab(ThemeData theme, bool isGlass) {
    if (_workLogs.isEmpty) return const Center(child: Text("Tasdiqlash uchun ish yo'q"));
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _workLogs.length,
      itemBuilder: (ctx, i) {
        final log = _workLogs[i];
        return Card(
          child: ListTile(
            title: Text(log['profiles']?['full_name'] ?? "Noma'lum"),
            subtitle: Text("${log['orders']?['order_number']}: ${log['task_type']} (${log['area_m2']} m2)"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _handleWork(log['id'], false)),
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _handleWork(log['id'], true)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvansTab(ThemeData theme, bool isGlass) {
    if (_withdrawals.isEmpty) return const Center(child: Text("Kutilayotgan avanslar yo'q"));
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _withdrawals.length,
      itemBuilder: (ctx, i) {
        final avans = _withdrawals[i];
        final f = NumberFormat("#,###");
        return Card(
          child: ListTile(
            title: Text(avans['profiles']?['full_name'] ?? "Noma'lum"),
            subtitle: Text("Summa: ${f.format(avans['amount'])} so'm\n${avans['description'] ?? ''}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => _handleAvans(avans['id'], false)),
                IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () => _handleAvans(avans['id'], true)),
              ],
            ),
          ),
        );
      },
    );
  }
}