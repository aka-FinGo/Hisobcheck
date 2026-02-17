import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // Parallel ravishda mijozlar va zakazlarni yuklaymiz
      final results = await Future.wait([
        _supabase.from('clients').select().order('name'),
        _supabase.from('orders').select('*, clients(name), work_logs(total_sum, is_approved)').order('created_at', ascending: false)
      ]);

      if (mounted) {
        setState(() {
          _clients = List<Map<String, dynamic>>.from(results[0]);
          _orders = List<Map<String, dynamic>>.from(results[1]);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MIJOZ QO'SHISH ---
  // ClientsScreen ichidagi mijoz qo'shish funksiyasi
void _showAddClientDialog() {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Yangi Mijoz"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController, 
            decoration: const InputDecoration(labelText: "Mijoz Ismi (F.I.SH)", border: OutlineInputBorder())
          ),
          const SizedBox(height: 10),
          TextField(
            controller: phoneController, 
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: "Telefon raqami", border: OutlineInputBorder())
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.trim().isEmpty) return;
            try {
              // Bazaga yozish
              await _supabase.from('clients').insert({
                'name': nameController.text.trim(),
                'phone': phoneController.text.trim(),
              });
              
              if (mounted) {
                Navigator.pop(ctx);
                // Ma'lumotlarni qayta yuklash
                _loadInitialData(); 
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Mijoz saqlandi"), backgroundColor: Colors.green)
                );
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red)
              );
            }
          },
          child: const Text("SAQLASH"),
        )
      ],
    ),
  );
}

  // --- ZAKAZ (LOYIHA) QO'SHISH ---
  void _showAddOrderDialog() {
    String? selectedClientId;
    final projectController = TextEditingController();
    final areaController = TextEditingController();
    final priceController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Yangi Loyiha (Zakaz)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Mijozni tanlang", border: OutlineInputBorder()),
                items: _clients.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
                onChanged: (v) => setModalState(() => selectedClientId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: projectController, decoration: const InputDecoration(labelText: "Loyiha nomi (Masalan: Oshxona)", border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(
                controller: areaController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: "O'lchangan kvadrat (m2)", border: OutlineInputBorder(), suffixText: "m2"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: "Jami shartnoma summasi", border: OutlineInputBorder(), suffixText: "so'm"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
  if (selectedClientId == null || projectController.text.isEmpty) return;
  
  // Mijoz ismini ro'yxatdan topib olamiz
  final client = _clients.firstWhere((c) => c['id'].toString() == selectedClientId);
  String clientName = client['name'].toString().replaceAll(' ', '-'); // Bo'shliqlarni chiziqqa almashtirish
  
  // Format: 100 (Zakaz ID qismi) _ 02 (Tartib) _ Ism-Loyiha
  // Hozircha oddiyroq vaqtga bog'langan ID ishlatamiz:
  String orderID = "100"; // Buni keyinchalik dinamik qilish mumkin
  String seq = DateTime.now().second.toString().padLeft(2, '0'); // Masalan 02
  String generatedProjectName = "${orderID}_${seq}_${clientName}_${projectController.text.replaceAll(' ', '-')}";

  await _supabase.from('orders').insert({
    'client_id': selectedClientId,
    'project_name': generatedProjectName, // Mana shu formatda saqlanadi
    'measured_area': double.tryParse(areaController.text) ?? 0,
    'total_price': double.tryParse(priceController.text) ?? 0,
    'order_number': generatedProjectName, // Qidiruv oson bo'lishi uchun
    'status': 'pending',
  });
  
  Navigator.pop(ctx);
  _loadInitialData();
},
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900),
                child: const Text("LOYIHANI OCHISH", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mijozlar va Loyihalar")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  title: Text("${order['clients']?['name']} - ${order['project_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Hajm: ${order['measured_area']} m² | Status: ${order['status']}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Zakaz detallari va moliyaviy hisobot sahifasiga o'tish
                  },
                ),
              );
            },
          ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: "btn1",
            onPressed: _showAddClientDialog,
            child: const Icon(Icons.person_add),
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "btn2",
            onPressed: _showAddOrderDialog,
            icon: const Icon(Icons.create_new_folder),
            label: const Text("Yangi Loyiha"),
            backgroundColor: Colors.blue.shade900,
          ),
        ],
      ),
    );
  }
}
