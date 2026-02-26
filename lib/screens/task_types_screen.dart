import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TaskTypesScreen extends StatefulWidget {
  const TaskTypesScreen({super.key});

  @override
  State<TaskTypesScreen> createState() => _TaskTypesScreenState();
}

class _TaskTypesScreenState extends State<TaskTypesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  List<dynamic> _filteredTasks = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final res = await _supabase.from('task_types').select().order('name');
      setState(() {
        _tasks = res;
        _filteredTasks = res;
      });
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterTasks(String query) {
    setState(() {
      _filteredTasks = _tasks
          .where((t) => t['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showTaskDialog({Map<String, dynamic>? task}) {
    final isEdit = task != null;
    final nameCtrl = TextEditingController(text: isEdit ? task['name'] : '');
    final priceCtrl = TextEditingController(text: isEdit ? task['price_per_unit'].toString() : '');
    final unitCtrl = TextEditingController(text: isEdit ? task['unit'] : 'dona');
    
    // YARATILGAN YANGI MANTIQ: Keyingi statusni tanlash
    String? targetStatus = isEdit ? task['target_status'] : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? "Tarifni tahrirlash" : "Yangi tarif"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ish nomi (M: Loyiha chizish)")),
                const SizedBox(height: 10),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Narxi (so'mda)"), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "O'lchov birligi (dona, m2, m/p)")),
                const SizedBox(height: 20),
                
                // AVTOMATIZATSIYA UCHUN DROPDOWN
                const Text("Avtomatizatsiya:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 5),
                DropdownButtonFormField<String?>(
                  value: targetStatus,
                  decoration: const InputDecoration(
                    labelText: "Ish topshirilgach, zakaz qaysi bosqichga o'tadi?",
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text("Status o'zgarmaydi")),
                    DropdownMenuItem(value: 'material', child: Text("Kesish/Material")),
                    DropdownMenuItem(value: 'assembly', child: Text("Yig'ish")),
                    DropdownMenuItem(value: 'delivery', child: Text("O'rnatish")),
                    DropdownMenuItem(value: 'completed', child: Text("Yakunlandi")),
                  ],
                  onChanged: (val) => setST(() => targetStatus = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  'name': nameCtrl.text,
                  'price_per_unit': double.tryParse(priceCtrl.text) ?? 0,
                  'unit': unitCtrl.text,
                  'target_status': targetStatus, // BAZAGA YOZAMIZ
                };
                if (isEdit) {
                  await _supabase.from('task_types').update(data).eq('id', task['id']);
                } else {
                  await _supabase.from('task_types').insert(data);
                }
                Navigator.pop(ctx);
                _fetchTasks();
              },
              child: const Text("Saqlash"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ishbay Tariflar"), elevation: 0),
      body: Column(
        children: [
          // Qidiruv paneli
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filterTasks,
              decoration: InputDecoration(
                hintText: "Tarifni qidirish...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredTasks.length,
                  itemBuilder: (context, index) {
                    final t = _filteredTasks[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.payments_outlined, color: Colors.orange),
                        ),
                        title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("1 ${t['unit']} = ${NumberFormat("#,###").format(t['price_per_unit'])} so'm"),
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => _showTaskDialog(task: t),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        label: const Text("Yangi Tarif"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
