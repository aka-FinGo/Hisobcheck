import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminTaskTypesScreen extends StatefulWidget {
  const AdminTaskTypesScreen({super.key});

  @override
  State<AdminTaskTypesScreen> createState() => _AdminTaskTypesScreenState();
}

class _AdminTaskTypesScreenState extends State<AdminTaskTypesScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, List<Map<String, dynamic>>> _groupedTasks = {};
  bool _isLoading = true;
  
  // Asosiy va bazadan keladigan barcha lavozimlar yig'indisi
  List<String> _availableRoles = ['admin', 'worker', 'installer', 'manager', 'designer'];

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
      
      final Map<String, List<Map<String, dynamic>>> tempGroup = {};
      final Set<String> dynamicRoles = {'admin', 'worker', 'installer', 'manager', 'designer'};

      for (var item in response) {
        final role = (item['target_role'] ?? 'Boshqa').toString().toLowerCase();
        dynamicRoles.add(role); // Mavjud rollarni ro'yxatga qo'shamiz

        final displayRole = role.toUpperCase();
        if (!tempGroup.containsKey(displayRole)) {
          tempGroup[displayRole] = [];
        }
        tempGroup[displayRole]!.add(item);
      }

      if (mounted) {
        setState(() {
          _groupedTasks = tempGroup;
          _availableRoles = dynamicRoles.toList(); // Dropdown uchun ro'yxatni yangilaymiz
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
    final rateController = TextEditingController(text: isEdit ? task['default_rate'].toString() : '');

    String selectedRole = isEdit ? task['target_role'].toString().toLowerCase() : 'worker';
    bool isCreatingNewRole = false;
    final newRoleController = TextEditingController();

    // Dialogdagi ro'yxatni shakllantirish
    List<String> dialogRoles = List.from(_availableRoles);
    if (!dialogRoles.contains(selectedRole)) dialogRoles.add(selectedRole);
    dialogRoles.add('+ Yangi lavozim yaratish');

    showDialog(
      context: context,
      // StatefulBuilder — oynaning ichidagi o'zgarishlarni darhol ekranga chiqarish uchun kerak
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(isEdit ? "Ta'rifni tahrirlash" : "Yangi ta'rif qo'shish"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  
                  // 1. AQLI RO'YXAT (DROPDOWN)
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: "Lavozimni tanlang", border: OutlineInputBorder()),
                    items: dialogRoles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(
                          role == '+ Yangi lavozim yaratish' ? role : role.toUpperCase(),
                          style: TextStyle(
                            color: role == '+ Yangi lavozim yaratish' ? Colors.blue : Colors.black,
                            fontWeight: role == '+ Yangi lavozim yaratish' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedRole = val!;
                        // Agar yangi yaratish bosilsa, pastda yozish qutisi ochiladi
                        isCreatingNewRole = selectedRole == '+ Yangi lavozim yaratish';
                      });
                    },
                  ),
                  const SizedBox(height: 10),

                  // 2. YANGI LAVOZIM UCHUN QUTI (Faqat "+ Yangi" tanlanganda chiqadi)
                  if (isCreatingNewRole) ...[
                    TextField(
                      controller: newRoleController,
                      decoration: const InputDecoration(labelText: "Yangi lavozim nomi (Masalan: Bo'yoqchi)", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                  ],

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
                  final rate = double.tryParse(rateController.text) ?? 0;
                  
                  // Qaysi rol tanlanganini aniqlash
                  String finalRole = selectedRole;
                  if (isCreatingNewRole) {
                    finalRole = newRoleController.text.trim().toLowerCase();
                  }

                  if (name.isEmpty || finalRole.isEmpty || finalRole == '+ yangi lavozim yaratish' || rate <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Barcha maydonlarni to'g'ri to'ldiring!")));
                    return;
                  }

                  try {
                    if (isEdit) {
                      await _supabase.from('task_types').update({
                        'name': name, 'target_role': finalRole, 'default_rate': rate,
                      }).eq('id', task['id']);
                    } else {
                      await _supabase.from('task_types').insert({
                        'name': name, 'target_role': finalRole, 'default_rate': rate,
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
          );
        }
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
                    String roleName = _groupedTasks.keys.elementAt(index);
                    List<Map<String, dynamic>> tasksInRole = _groupedTasks[roleName]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                          child: Text(
                            "LAVOZIM: $roleName",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                          ),
                        ),
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
                        const SizedBox(height: 10),
                      ],
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
