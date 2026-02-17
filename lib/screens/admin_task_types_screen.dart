import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTaskTypesScreen extends StatefulWidget {
  const AdminTaskTypesScreen({super.key});

  @override
  State<AdminTaskTypesScreen> createState() => _AdminTaskTypesScreenState();
}

class _AdminTaskTypesScreenState extends State<AdminTaskTypesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final data = await _supabase.from('task_types').select().order('name');
    if (mounted) setState(() { _tasks = List<Map<String, dynamic>>.from(data); _isLoading = false; });
  }

  // Yangi ish turi qo'shish yoki tahrirlash
  void _showTaskDialog({Map<String, dynamic>? task}) {
    final nameController = TextEditingController(text: task?['name'] ?? '');
    final rateController = TextEditingController(text: task?['default_rate']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(task == null ? "Yangi Ish Turi" : "Tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Ish nomi (Masalan: Kromka)")),
            const SizedBox(height: 10),
            TextField(controller: rateController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Standart Narx (so'm)", suffixText: "so'm")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || rateController.text.isEmpty) return;
              try {
                final data = {
                  'name': nameController.text,
                  'default_rate': double.tryParse(rateController.text) ?? 0,
                };

                if (task == null) {
                  await _supabase.from('task_types').insert(data);
                } else {
                  await _supabase.from('task_types').update(data).eq('id', task['id']);
                }
                
                Navigator.pop(ctx);
                _loadTasks();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saqlandi!")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }

  // O'chirish
  Future<void> _deleteTask(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: const Text("Bu ish turini o'chirmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('task_types').delete().eq('id', id);
      _loadTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ish Turlari va Narxlar")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _tasks.length,
            itemBuilder: (ctx, i) {
              final task = _tasks[i];
              return Card(
                child: ListTile(
                  title: Text(task['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Standart narx: ${task['default_rate']} so'm"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showTaskDialog(task: task)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTask(task['id'])),
                    ],
                  ),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}