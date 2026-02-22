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
    _fetchTasks();
  }

  // Bazadan barcha lavozimlar va ularning ta'riflarini yuklash
  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('task_types')
          .select()
          .order('target_role', ascending: true);
      
      if (mounted) {
        setState(() {
          _tasks = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint("Tasks yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Yangi qo'shish yoki tahrirlash oynasi (Dialog)
  void _showTaskDialog({Map<String, dynamic>? task}) {
    final isEdit = task != null;
    final nameController = TextEditingController(text: isEdit ? task['name'] : '');
    final roleController = TextEditingController(text: isEdit ? task['target_role'] : '');
    final rateController = TextEditingController(text: isEdit ? task['default_rate'].toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Ta'rifni tahrirlash" : "Yangi lavozim va ta'rif"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: "Lavozim (Masalan: arrachi, kraymchi)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Ish nomi (Masalan: Arralash 18mm)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Ta'rif (1 m² yoki 1 dona uchun narx)", border: OutlineInputBorder(), suffixText: "so'm"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
            onPressed: () async {
              final name = nameController.text.trim();
              final role = roleController.text.trim();
              final rate = double.tryParse(rateController.text) ?? 0;

              if (name.isEmpty || role.isEmpty || rate <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barcha maydonlarni to'g'ri to'ldiring!")));
                return;
              }

              try {
                if (isEdit) {
                  await _supabase.from('task_types').update({
                    'name': name,
                    'target_role': role,
                    'default_rate': rate,
                  }).eq('id', task['id']);
                } else {
                  await _supabase.from('task_types').insert({
                    'name': name,
                    'target_role': role,
                    'default_rate': rate,
                  });
                }
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _fetchTasks();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Muvaffaqiyatli saqlandi!"), backgroundColor: Colors.green));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SAQLASH"),
          )
        ],
      ),
    );
  }

  // Lavozim va tarifni o'chirish
  void _deleteTask(int id) async {
    try {
      await _supabase.from('task_types').delete().eq('id', id);
      _fetchTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("O'chirishda xatolik: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: const Text("Lavozimlar va Ta'riflar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF2E5BFF),
                      child: Icon(Icons.work, color: Colors.white),
                    ),
                    title: Text(task['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 5),
                        Text("Lavozim: ${task['target_role'].toString().toUpperCase()}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        Text("Ta'rif: ${task['default_rate']} so'm / m²", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                      ],
                    ),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E5BFF),
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yangi Ta'rif", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
