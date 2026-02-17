import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientDetailsScreen({super.key, required this.client});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientOrders = [];
  Map<String, dynamic> _clientData = {}; // Tahrirlanganda yangilanib turishi uchun

  @override
  void initState() {
    super.initState();
    _clientData = widget.client;
    _loadClientOrders();
  }

  Future<void> _loadClientOrders() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('orders')
          .select('*, work_logs(total_sum)') // Work logs orqali xarajatlarni ham ko'rish mumkin
          .eq('client_id', _clientData['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _clientOrders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- MIJOZNI TAHRIRLASH ---
  void _editClientDialog() {
    final nameController = TextEditingController(text: _clientData['full_name'] ?? _clientData['name']);
    final phoneController = TextEditingController(text: _clientData['phone']);
    final addressController = TextEditingController(text: _clientData['address']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mijozni Tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "F.I.SH", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: addressController, decoration: const InputDecoration(labelText: "Manzil", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              try {
                final updates = {
                  'full_name': nameController.text,
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'address': addressController.text,
                };
                
                // Bazada yangilash
                final res = await _supabase.from('clients').update(updates).eq('id', _clientData['id']).select().single();
                
                setState(() {
                  _clientData = res; // Ekranni yangilash
                });
                
                if (mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mijoz yangilandi!"), backgroundColor: Colors.green));
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

  // --- MIJOZNI O'CHIRISH ---
  void _deleteClient() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Mijozni o'chirish"),
        content: const Text("Diqqat! Agar mijoz o'chirilsa, uning barcha zakazlari ham o'chib ketishi mumkin. Tasdiqlaysizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA, O'CHIRILSIN", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('clients').delete().eq('id', _clientData['id']);
      if (mounted) {
        Navigator.pop(context, true); // Orqaga "yangilanish kerak" degan signal bilan qaytish
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_clientData['full_name'] ?? "Mijoz ma'lumotlari"),
        actions: [
          IconButton(onPressed: _editClientDialog, icon: const Icon(Icons.edit, color: Colors.blue)),
          IconButton(onPressed: _deleteClient, icon: const Icon(Icons.delete, color: Colors.red)),
        ],
      ),
      body: Column(
        children: [
          // 1. MIJOZ HAQIDA QISQA INFO
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                const CircleAvatar(radius: 30, child: Icon(Icons.person, size: 30)),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_clientData['full_name'] ?? "", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(_clientData['phone'] ?? "Tel yo'q", style: const TextStyle(color: Colors.grey)),
                    Text(_clientData['address'] ?? "Manzil yo'q", style: const TextStyle(color: Colors.grey)),
                  ],
                )
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Align(alignment: Alignment.centerLeft, child: Text("Mijoz Zakazlari:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          
          // 2. ZAKAZLAR RO'YXATI
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _clientOrders.isEmpty 
                ? const Center(child: Text("Hozircha zakazlar yo'q"))
                : ListView.builder(
                    itemCount: _clientOrders.length,
                    itemBuilder: (ctx, i) {
                      final order = _clientOrders[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          title: Text(order['project_name'] ?? "Nomsiz"),
                          subtitle: Text("Summa: ${order['total_price']} so'm\nStatus: ${order['status']}"),
                          isThreeLine: true,
                          trailing: Icon(Icons.circle, color: _getStatusColor(order['status'])),
                          onTap: () {
                            // Kelajakda: Zakaz ichiga kirib uni tahrirlash sahifasiga o'tish
                          },
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'completed': return Colors.green;
      case 'in_progress': return Colors.blue;
      default: return Colors.grey;
    }
  }
}
