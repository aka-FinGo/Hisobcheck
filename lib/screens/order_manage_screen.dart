import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderManageScreen extends StatefulWidget {
  const OrderManageScreen({super.key});
  @override
  State<OrderManageScreen> createState() => _OrderManageScreenState();
}

class _OrderManageScreenState extends State<OrderManageScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final data = await _supabase.from('orders').select().order('created_at');
    setState(() => _orders = data);
  }

  // Kvadratni yangilash dialogi
  void _editOrderArea(dynamic order) {
    final areaCtrl = TextEditingController(text: order['total_area_m2']?.toString() ?? "");
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${order['order_number']} kvadratini kiritish"),
        content: TextField(
          controller: areaCtrl,
          decoration: const InputDecoration(labelText: "Umumiy kvadrat (m2)", border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('orders').update({
                'total_area_m2': double.parse(areaCtrl.text),
              }).eq('id', order['id']);
              Navigator.pop(context);
              _loadOrders();
            }, 
            child: const Text("SAQLASH")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Zakazlar kvadrati (Bek)")),
      body: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, i) {
          final o = _orders[i];
          return ListTile(
            title: Text(o['order_number']),
            subtitle: Text("Mijoz: ${o['client_name'] ?? 'Noma''lum'}"),
            trailing: Text("${o['total_area_m2'] ?? 0} m²", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onTap: () => _editOrderArea(o),
          );
        },
      ),
    );
  }
}
