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

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('orders').select().order('created_at', ascending: false);
      setState(() {
        _orders = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  // Status rangini aniqlash
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in_progress': return Colors.blue;
      case 'ready': return Colors.purple;
      case 'completed': return Colors.green;
      case 'canceled': return Colors.red;
      default: return Colors.grey;
    }
  }

  // Status nomini o'zbekcha qilish
  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return "Kutilmoqda";
      case 'in_progress': return "Jarayonda";
      case 'ready': return "Tayyor";
      case 'completed': return "Yopildi";
      case 'canceled': return "Bekor qilindi";
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mijozlar va Zakazlar"),
        actions: [
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getStatusColor(order['status']).withOpacity(0.1),
                    child: Icon(Icons.assignment, color: _getStatusColor(order['status'])),
                  ),
                  title: Text(
                    "№${order['order_number']} - ${order['client_name'] ?? 'Noma\'lum'}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Muddat: ${order['deadline'] ?? 'Belgilanmagan'}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order['status']),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _getStatusText(order['status']),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildOrderInfoRow("Umumiy summa:", "${order['total_price']} so'm"),
                          _buildOrderInfoRow("Telefon:", order['client_phone'] ?? "Yo'q"),
                          const Divider(),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _changeStatusDialog(order),
                                icon: const Icon(Icons.edit_notifications),
                                label: const Text("Status"),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Bu yerda zakazga tegishli ishlar tarixini ko'rsatish mumkin
                                },
                                icon: const Icon(Icons.history),
                                label: const Text("Ishlar"),
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrderDialog,
        label: const Text("Yangi Zakaz"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade900,
      ),
    );
  }

  Widget _buildOrderInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Statusni o'zgartirish dialogi
  void _changeStatusDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Statusni yangilash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['pending', 'in_progress', 'ready', 'completed', 'canceled'].map((s) {
            return ListTile(
              title: Text(_getStatusText(s)),
              onTap: () async {
                await _supabase.from('orders').update({'status': s}).eq('id', order['id']);
                Navigator.pop(ctx);
                _loadOrders();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // Yangi zakaz qo'shish dialogi
  void _showAddOrderDialog() {
    final numController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yangi Zakaz Qo'shish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: numController, decoration: const InputDecoration(labelText: "Zakaz №", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Mijoz ismi", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Umumiy Summa", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('orders').insert({
                  'order_number': numController.text,
                  'client_name': nameController.text,
                  'total_price': double.tryParse(priceController.text) ?? 0,
                  'status': 'pending',
                });
                Navigator.pop(ctx);
                _loadOrders();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade900),
              child: const Text("SAQLASH", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}