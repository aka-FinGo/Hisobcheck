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
  List<dynamic> _clients = [];

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('clients').select().order('created_at', ascending: false);
      setState(() {
        _clients = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // --- MIJOZ QO'SHISH ---
  void _addClientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yangi Buyurtmachi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ismi (m: Anvar aka)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              try {
                await _supabase.from('clients').insert({
                  'full_name': nameCtrl.text,
                  'phone': phoneCtrl.text,
                });
                Navigator.pop(context);
                _loadClients();
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

  // --- ZAKAZ OCHISH (BEK UCHUN) ---
  void _showAddOrderDialog(dynamic client) {
    final orderNumCtrl = TextEditingController();
    final typeCtrl = TextEditingController(); // Oshxona...
    final areaCtrl = TextEditingController(); // Kvadrat...

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${client['full_name']}ga zakaz"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: orderNumCtrl, decoration: const InputDecoration(labelText: "Zakaz № (m: 100_02)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: "Loyiha turi (m: Oshxona)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: "Kvadrat (m²)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              if (orderNumCtrl.text.isEmpty || areaCtrl.text.isEmpty) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Raqam va Kvadrat kiritilishi shart!")));
                 return;
              }
              
              try {
                await _supabase.from('orders').insert({
                  'order_number': orderNumCtrl.text,
                  'client_id': client['id'],
                  'project_type': typeCtrl.text,
                  'total_area_m2': double.parse(areaCtrl.text),
                  'status': 'new',
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz muvaffaqiyatli ochildi!")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("ZAKAZNI OCHISH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mijozlar & Zakazlar")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClientDialog,
        child: const Icon(Icons.person_add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _clients.length,
              itemBuilder: (context, index) {
                final client = _clients[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(client['full_name'][0])),
                    title: Text(client['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(client['phone'] ?? ''),
                    trailing: ElevatedButton.icon(
                      onPressed: () => _showAddOrderDialog(client),
                      icon: const Icon(Icons.add_task, size: 16),
                      label: const Text("Zakaz"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
