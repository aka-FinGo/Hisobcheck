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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
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
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint("Yuklashda xato: $e");
      }
    }
  }

  // --- MIJOZ QO'SHISH ---
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
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "F.I.SH", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await _supabase.from('clients').insert({
                  'name': nameController.text.trim(), 
                  'phone': phoneController.text.trim()
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  _loadInitialData();
                }
              } catch (e) {
                debugPrint("Mijoz saqlashda xato: $e");
              }
            },
            child: const Text("SAQLASH"),
          ),
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: "O'lchangan kvadrat (m2)", border: OutlineInputBorder(), suffixText: "m2"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(labelText: "Shartnoma summasi", border: OutlineInputBorder(), suffixText: "so'm"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  if (selectedClientId == null || projectController.text.isEmpty) return;
                  
                  final client = _clients.firstWhere((c) => c['id'].toString() == selectedClientId);
                  String clientSafeName = client['name'].toString().replaceAll(' ', '-');
                  
                  // Format: 100_01_Ism_Loyiha
                  String prefix = "100";
                  String seq = (_orders.length + 1).toString().padLeft(2, '0');
                  String generatedName = "${prefix}_${seq}_${clientSafeName}_${projectController.text.replaceAll(' ', '-')}";

                  try {
                    await _supabase.from('orders').insert({
                      'client_id': selectedClientId,
                      'project_name': generatedName,
                      'measured_area': double.tryParse(areaController.text.replaceAll(',', '.')) ?? 0,
                      'total_price': double.tryParse(priceController.text) ?? 0,
                      'order_number': generatedName,
                      'status': 'pending',
                    });
                    if (mounted) {
                      Navigator.pop(ctx);
                      _loadInitialData();
                    }
                  } catch (e) {
                    debugPrint("Order saqlashda xato: $e");
                  }
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
                  title: Text("${order['project_name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Hajm: ${order['measured_area']} m² | Status: ${order['status']}"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Detallar sahifasiga o'tish mantiqi
                  },
                ),
              );
            },
          ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: "add_client",
            onPressed: _showAddClientDialog,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.person_add, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: "add_order",
            onPressed: _showAddOrderDialog,
            icon: const Icon(Icons.create_new_folder),
            label: const Text("Yangi Loyiha"),
            backgroundColor: Colors.blue.shade900,
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
