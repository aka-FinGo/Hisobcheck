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

  // Zakazni tahrirlash (Status yoki Kvadrat)
  void _editOrder(dynamic order) {
    final statusCtrl = TextEditingController(text: order['status']);
    final areaCtrl = TextEditingController(text: order['total_area_m2'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Zakaz: ${order['order_number']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: areaCtrl, decoration: const InputDecoration(labelText: "Kvadrat (m²)"), keyboardType: TextInputType.number),
            const SizedBox(height: 10),
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
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Telefon: ${widget.client['phone'] ?? '-'}", style: const TextStyle(fontSize: 16)),
                Text("Manzil: ${widget.client['address'] ?? '-'}", style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _orders.isEmpty 
              ? const Center(child: Text("Zakazlar yo'q"))
              : ListView.builder(
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(order['status'] == 'completed' ? Icons.check_circle : Icons.timelapse, 
                                      color: order['status'] == 'completed' ? Colors.green : Colors.orange),
                        title: Text("№ ${order['order_number']} (${order['project_type']})"),
                        subtitle: Text("Hajm: ${order['total_area_m2']} m²"),
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
