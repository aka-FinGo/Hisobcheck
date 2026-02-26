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
    final priceCtrl = TextEditingController(text: isEdit ? task['price_per_unit']?.toString() : '0');
    final unitCtrl = TextEditingController(text: isEdit ? task['unit'] : 'dona');
    
    // AVTOMATIZATSIYA: Keyingi status
    String? targetStatus = isEdit ? task['target_status'] : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setST) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? "Tarifni tahrirlash" : "Yangi tarif"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ish nomi (M: Kromka urish)", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: "Birlik (dona, m2)", border: OutlineInputBorder())),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: "Narxi", border: OutlineInputBorder()), keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // AVTOMATIZATSIYA QISMI
                const Text("Avtomatizatsiya (Pipeline)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: targetStatus,
                  decoration: const InputDecoration(
                    labelText: "Ushbu ish topshirilgach...",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: null, child: Text("Status o'zgarmaydi")),
                    DropdownMenuItem(value: 'material', child: Text("Kesish/Material ->")),
                    DropdownMenuItem(value: 'assembly', child: Text("Yig'ish ->")),
                    DropdownMenuItem(value: 'delivery', child: Text("O'rnatish ->")),
                    DropdownMenuItem(value: 'completed', child: Text("Yakunlandi")),
                  ],
                  onChanged: (val) => setST(() => targetStatus = val),
                ),
              ],
            ),
          ),
          actions: [
            // O'CHIRISH TUGMASI
            if (isEdit)
              TextButton(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text("Diqqat!"),
                      content: const Text("Ushbu tarifni o'chirmoqchimisiz?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Yo'q")),
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
                      await _supabase.from('task_types').delete().eq('id', task['id']);
                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchTasks();
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xatolik: Bu tarif ishlatilgan bo'lishi mumkin!"), backgroundColor: Colors.red));
                    }
                  }
                },
                child: const Text("O'chirish", style: TextStyle(color: Colors.red)),
              ),

            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor")),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                final data = {
                  'name': nameCtrl.text,
                  'price_per_unit': double.tryParse(priceCtrl.text) ?? 0,
                  'unit': unitCtrl.text,
                  'target_status': targetStatus,
                };
                try {
                  if (isEdit) {
                    await _supabase.from('task_types').update(data).eq('id', task['id']);
                  } else {
                    await _supabase.from('task_types').insert(data);
                  }
                  if (mounted) {
                    Navigator.pop(ctx);
                    _fetchTasks();
                  }
                } catch (e) {
                  debugPrint("Saqlashda xato: $e");
                }
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
                    
                    // Status qayerga o'tishini yozuvda ko'rsatish
                    String targetDisplay = "Status o'zgarmaydi";
                    if (t['target_status'] == 'material') targetDisplay = "-> Kesish";
                    if (t['target_status'] == 'assembly') targetDisplay = "-> Yig'ish";
                    if (t['target_status'] == 'delivery') targetDisplay = "-> O'rnatish";
                    if (t['target_status'] == 'completed') targetDisplay = "-> Yakunlandi";

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: const Icon(Icons.payments_outlined, color: Colors.orange),
                        ),
                        title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("1 ${t['unit']} = ${NumberFormat("#,###").format(t['price_per_unit'])} so'm"),
                            Text(targetDisplay, style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
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
        backgroundColor: const Color(0xFF2E5BFF),
        onPressed: () => _showTaskDialog(),
        label: const Text("Yangi Tarif", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
