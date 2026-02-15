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
    final data = await _supabase.from('clients').select().order('created_at', ascending: false);
    setState(() {
      _clients = data;
      _isLoading = false;
    });
  }

  // YANGI MIJOZ QO'SHISH DIALOGI
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
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ismi (m: Anvar aka)", prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon", prefixIcon: Icon(Icons.phone)), keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Manzil", prefixIcon: Icon(Icons.location_on))),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
            child: const Text("SAQLASH"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buyurtmachilar Bazasi")),
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
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(client['full_name'][0].toUpperCase()),
                    ),
                    title: Text(client['full_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${client['phone'] ?? ''} | ${client['address'] ?? ''}"),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_task, color: Colors.green),
                      onPressed: () {
                        // BU YERDA SHU MIJOZGA ZAKAZ QO'SHISH OCHILADI (Keyingi bosqich)
                        _showAddOrderDialog(client);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }

  // MIJOZGA ZAKAZ BIRIKTIRISH (Anvar aka -> Oshxona -> 50kv)
  void _showAddOrderDialog(dynamic client) {
    final orderNumCtrl = TextEditingController();
    final typeCtrl = TextEditingController(); // Oshxona, Yotoqxona...
    final areaCtrl = TextEditingController(); // Kvadrat (Bek kiritadi)

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
              
              // 1. ZAKAZ YARATISH
              await _supabase.from('orders').insert({
                'order_number': orderNumCtrl.text,
                'client_id': client['id'],
                'project_type': typeCtrl.text,
                'total_area_m2': double.parse(areaCtrl.text),
                'status': 'new', // Yangi zakaz
              });

              // 2. AGAR BU BEK BO'LSA, UNGA ISH HAQI YOZISH MANTIG'I SHU YERDA BO'LADI
              // Hozircha faqat zakazni yaratdik.

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz yaratildi va Bek uchun maydon tayyorlandi!")));
              }
            },
            child: const Text("ZAKAZ OCHISH"),
          ),
        ],
      ),
    );
  }
}
