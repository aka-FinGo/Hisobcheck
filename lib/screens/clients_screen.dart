import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'client_details_screen.dart'; // <--- IMPORT MUHIM!

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
    setState(() { _clients = data; _isLoading = false; });
  }

  void _addClientDialog() {
    // ... (Oldingi kod bilan bir xil, o'zgarishsiz qoldiring) ...
    // Qisqartirish uchun bu yerni takror yozmadim, eski koddagidek qolaversin
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
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Ismi")),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: "Telefon")),
            TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: "Manzil")),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () async {
             await _supabase.from('clients').insert({
               'full_name': nameCtrl.text, 'phone': phoneCtrl.text, 'address': addressCtrl.text
             });
             Navigator.pop(context); _loadClients();
          }, child: const Text("Saqlash"))
        ],
      ),
    );
  }

  // Zakaz ochish (O'zgarishsiz)
  void _showAddOrderDialog(dynamic client) {
     // ... (Oldingi kod bilan bir xil) ...
     // Bu yerda faqat Supabasega insert qiladigan mantiq turibdi
     final orderNumCtrl = TextEditingController();
     final typeCtrl = TextEditingController();
     final areaCtrl = TextEditingController();
     
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text("Zakaz: ${client['full_name']}"),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(controller: orderNumCtrl, decoration: const InputDecoration(labelText: "Zakaz №")),
             TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: "Turi (Oshxona)")),
             TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: "Kvadrat m2")),
           ],
         ),
         actions: [
           ElevatedButton(onPressed: () async {
             await _supabase.from('orders').insert({
               'order_number': orderNumCtrl.text, 'client_id': client['id'],
               'project_type': typeCtrl.text, 'total_area_m2': double.parse(areaCtrl.text),
               'status': 'new'
             });
             Navigator.pop(context);
           }, child: const Text("Ochish"))
         ],
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mijozlar")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClientDialog,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _clients.length,
        itemBuilder: (context, index) {
          final client = _clients[index];
          return Card(
            child: ListTile(
              title: Text(client['full_name']),
              subtitle: Text(client['phone'] ?? ''),
              trailing: IconButton(
                icon: const Icon(Icons.add_task),
                onPressed: () => _showAddOrderDialog(client),
              ),
              // --- MANA BU YER ISHLAYDI ENDI ---
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ClientDetailsScreen(client: client)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
