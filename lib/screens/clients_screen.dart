import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_details_screen.dart'; // Agar tafsilotlar sahifasini qilsangiz kerak bo'ladi

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

  // --- YANGI MIJOZ QO'SHISH ---
  void _addClientDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

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
            const SizedBox(height: 10),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Manzil", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor")),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              await _supabase.from('clients').insert({
                'full_name': nameCtrl.text,
                'phone': phoneCtrl.text,
                'address': addressCtrl.text,
              });
              Navigator.pop(context);
              _loadClients();
            },
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }

  // --- MIJOZGA ZAKAZ OCHISH (BEK UCHUN) ---
  void _showAddOrderDialog(dynamic client) {
    final orderNumCtrl = TextEditingController();
    final typeCtrl = TextEditingController();
    final areaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${client['full_name']}ga zakaz ochish"),
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
              if (orderNumCtrl.text.isEmpty || areaCtrl.text.isEmpty) return;
              
              await _supabase.from('orders').insert({
                'order_number': orderNumCtrl.text,
                'client_id': client['id'],
                'project_type': typeCtrl.text,
                'total_area_m2': double.parse(areaCtrl.text),
                'status': 'new',
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz ochildi!")));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("ZAKAZ YARATISH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mijozlar Bazasi")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClientDialog,
        backgroundColor: Colors.blue.shade900,
        child: const Icon(Icons.person_add, color: Colors.white),
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
                    leading: CircleAvatar(child: Text(client['full_name'][0].toUpperCase())),
                    title: Text(client['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(client['phone'] ?? ''),
                    // O'ng tomonda zakaz ochish tugmasi
                    trailing: IconButton(
                      icon: const Icon(Icons.add_task, color: Colors.blue),
                      onPressed: () => _showAddOrderDialog(client),
                      tooltip: "Zakaz qo'shish",
                    ),
                    // Bosilganda tafsilotlar (keyinchalik qo'shishingiz mumkin)
                    onTap: () {
                       // Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailsScreen(client: client)));
                    },
                  ),
                );
              },
            ),
    );
  }
}
