import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTaskTypesScreen extends StatefulWidget {
  const AdminTaskTypesScreen({super.key});

  @override
  State<AdminTaskTypesScreen> createState() => _AdminTaskTypesScreenState();
}

class _AdminTaskTypesScreenState extends State<AdminTaskTypesScreen> {
  final _supabase = Supabase.instance.client;
  // Endi ma'lumotlarni lavozim nomiga qarab guruhlaymiz
  Map<String, List<Map<String, dynamic>>> _groupedTasks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('task_types')
          .select()
          .order('target_role', ascending: true);
      
      // Ro'yxatdan kelgan ma'lumotlarni "target_role" bo'yicha guruhlarga ajratamiz
      final Map<String, List<Map<String, dynamic>>> tempGroup = {};
      for (var item in response) {
        final role = (item['target_role'] ?? 'Boshqa').toString().toUpperCase();
        if (!tempGroup.containsKey(role)) {
          tempGroup[role] = [];
        }
        tempGroup[role]!.add(item);
      }

      if (mounted) {
        setState(() {
          _groupedTasks = tempGroup;
        });
      }
    } catch (e) {
      debugPrint("Tasks yuklashda xato: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
                decoration: const InputDecoration(labelText: "Lavozim (Masalan: arrachi)", border: OutlineInputBorder()),
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
                decoration: const InputDecoration(labelText: "Ta'rif (so'm)", border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF)),
            onPressed: () async {
              final name = nameController.text.trim();
              final role = roleController.text.trim().toLowerCase(); // Bazada har doim kichik harfda saqlaymiz
              final rate = double.tryParse(rateController.text) ?? 0;

              if (name.isEmpty || role.isEmpty || rate <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To'g'ri to'ldiring!")));
                return;
              }

              try {
                if (isEdit) {
                  await _supabase.from('task_types').update({
                    'name': name, 'target_role': role, 'default_rate': rate,
                  }).eq('id', task['id']);
                } else {
                  await _supabase.from('task_types').insert({
                    'name': name, 'target_role': role, 'default_rate': rate,
                  });
                }
                
                if (mounted) {
                  Navigator.pop(ctx);
                  _fetchTasks();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            child: const Text("SAQLASH", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _deleteTask(int id) async {
    try {
      await _supabase.from('task_types').delete().eq('id', id);
      _fetchTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e")));
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
          : _groupedTasks.isEmpty
              ? const Center(child: Text("Hali ta'riflar qo'shilmagan"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groupedTasks.keys.length,
                  itemBuilder: (context, index) {
                    // Guruhlangan lavozim nomlarini olamiz (Masalan: ARRACHI, KRAYMCHI)
                    String roleName = _groupedTasks.keys.elementAt(index);
                    List<Map<String, dynamic>> tasksInRole = _groupedTasks[roleName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lavozim sarlavhasi
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                          child: Text(
                            "LAVOZIM: $roleName",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                        ),
                        // Shu lavozimga tegishli barcha ishlar
                        ...tasksInRole.map((task) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: ListTile(
                            title: Text(task['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${task['default_rate']} so'm", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showTaskDialog(task: task)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTask(task['id'])),
                              ],
                            ),
                          ),
                        )).toList(),
                        const SizedBox(height: 10), // Guruhlar orasidagi bo'shliq
                      ],
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E5BFF),
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Yangi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
