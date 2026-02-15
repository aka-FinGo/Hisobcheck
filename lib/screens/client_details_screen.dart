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
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final data = await _supabase
        .from('orders')
        .select()
        .eq('client_id', widget.client['id'])
        .order('created_at', ascending: false);
    setState(() {
      _orders = data;
      _isLoading = false;
    });
  }

  // ZAKAZNI TAHRIRLASH
  void _editOrder(Map<String, dynamic> order) {
    final areaCtrl = TextEditingController(text: order['total_area_m2'].toString());
    final statusCtrl = TextEditingController(text: order['status']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Zakaz №${order['order_number']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: "Kvadrat (m²)")),
            const SizedBox(height: 10),
            // Statusni o'zgartirish (Dropdown qilish ham mumkin)
            TextField(controller: statusCtrl, decoration: const InputDecoration(labelText: "Status (new, completed)")),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('orders').update({
                'total_area_m2': double.parse(areaCtrl.text),
                'status': statusCtrl.text,
              }).eq('id', order['id']);
              Navigator.pop(context);
              _loadOrders();
            },
            child: const Text("SAQLASH"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client['full_name'])),
      body: Column(
        children: [
          ListTile(
            title: const Text("Mijoz Ma'lumotlari", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Tel: ${widget.client['phone']}\nManzil: ${widget.client['address'] ?? '-'}"),
            tileColor: Colors.grey.shade200,
          ),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _orders.length,
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      return Card(
                        margin: const EdgeInsets.all(8),
                        child: ListTile(
                          title: Text("${order['order_number']} (${order['project_type']})"),
                          subtitle: Text("Kvadrat: ${order['total_area_m2']} m²\nStatus: ${order['status']}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editOrder(order),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
