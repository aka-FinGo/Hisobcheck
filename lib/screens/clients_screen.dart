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
      // Zakazlarni va ularga tegishli barcha ish haqlarini (work_logs) bittada olamiz
      final response = await _supabase
          .from('orders')
          .select('*, work_logs(total_sum, is_approved)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  // Moliyaviy hisob-kitob funksiyasi
  Map<String, double> _calculateFinances(List workLogs, double totalPrice) {
    double totalExpenses = 0;
    for (var log in workLogs) {
      // Faqat tasdiqlangan ish haqlarini xarajatga qo'shamiz
      if (log['is_approved'] == true) {
        totalExpenses += (log['total_sum'] ?? 0).toDouble();
      }
    }
    return {
      'expenses': totalExpenses,
      'profit': totalPrice - totalExpenses,
    };
  }

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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Mijozlar va Zakazlar"),
        actions: [
          IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _orders.isEmpty 
          ? const Center(child: Text("Zakazlar mavjud emas"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final finances = _calculateFinances(
                  order['work_logs'] ?? [], 
                  (order['total_price'] ?? 0).toDouble()
                );

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(order['status']).withOpacity(0.1),
                      child: Icon(Icons.kitchen, color: _getStatusColor(order['status'])),
                    ),
                    title: Text(
                      "№${order['order_number']} - ${order['client_name'] ?? 'Mijoz'}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Muddat: ${order['deadline'] ?? 'Aytilmagan'}"),
                    trailing: _statusBadge(order['status']),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _financeRow("Mijoz to'lovi (Narx):", order['total_price'], Colors.black),
                            _financeRow("Ishchilar haqi (Xarajat):", finances['expenses'], Colors.red),
                            const Divider(),
                            _financeRow("Sof Foyda:", finances['profit'], Colors.green, isBold: true),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _changeStatusDialog(order),
                                    icon: const Icon(Icons.edit_note),
                                    label: const Text("Statusni o'zgartirish"),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                IconButton.filledTonal(
                                  onPressed: () => _deleteOrder(order['id']),
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
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
        icon: const Icon(Icons.add_business),
        label: const Text("Yangi Zakaz"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _statusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusText(status),
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _financeRow(String label, dynamic val, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            "${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so'm",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
              fontSize: isBold ? 16 : 14
            ),
          ),
        ],
      ),
    );
  }

  void _changeStatusDialog(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text("Zakaz holatini tanlang", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...['pending', 'in_progress', 'ready', 'completed', 'canceled'].map((s) {
            return ListTile(
              leading: Icon(Icons.circle, color: _getStatusColor(s)),
              title: Text(_getStatusText(s)),
              onTap: () async {
                await _supabase.from('orders').update({'status': s}).eq('id', order['id']);
                Navigator.pop(ctx);
                _loadOrders();
              },
            );
          }).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAddOrderDialog() {
    final numController = TextEditingController();
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final dateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yangi Zakaz", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: numController, decoration: const InputDecoration(labelText: "Zakaz Raqami (№)", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Mijoz Ismi", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Umumiy Kelishilgan Narx", border: OutlineInputBorder(), suffixText: "so'm")),
            const SizedBox(height: 12),
            TextField(
              controller: dateController, 
              decoration: const InputDecoration(labelText: "Muddat (YYYY-MM-DD)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
              onTap: () async {
                DateTime? pickedDate = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                if (pickedDate != null) dateController.text = pickedDate.toString().split(' ')[0];
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (numController.text.isEmpty) return;
                await _supabase.from('orders').insert({
                  'order_number': numController.text,
                  'client_name': nameController.text,
                  'total_price': double.tryParse(priceController.text) ?? 0,
                  'deadline': dateController.text.isEmpty ? null : dateController.text,
                  'status': 'pending',
                });
                Navigator.pop(ctx);
                _loadOrders();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blue.shade900),
              child: const Text("ZAKAZNI SAQLASH", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _deleteOrder(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("O'chirish"),
        content: const Text("Ushbu zakazni o'chirmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.from('orders').delete().eq('id', id);
      _loadOrders();
    }
  }
}