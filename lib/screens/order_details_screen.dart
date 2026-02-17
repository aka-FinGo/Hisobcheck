import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // Sana formati uchun (pubspec.yaml ga intl qo'shish kerak bo'lishi mumkin)

class OrderDetailsScreen extends StatefulWidget {
  final int orderId; // Bizga faqat ID kerak, qolganini yangilab olamiz

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic> _order = {};
  List<Map<String, dynamic>> _workLogs = [];
  
  // Moliyaviy hisoblar
  double _totalExpenses = 0;
  double _profit = 0;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Zakaz ma'lumotlari + Mijoz ismi
      final orderRes = await _supabase
          .from('orders')
          .select('*, clients(full_name, phone)')
          .eq('id', widget.orderId)
          .single();

      // 2. Shu zakaz bo'yicha qilingan ishlar (Jarayon tarixi)
      final logsRes = await _supabase
          .from('work_logs')
          .select('*, profiles(full_name)') // Ishchi ismini olish uchun
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: false);

      // 3. Xarajatlarni hisoblash
      double expenses = 0;
      final logs = List<Map<String, dynamic>>.from(logsRes);
      for (var log in logs) {
        expenses += (log['total_sum'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _order = orderRes;
          _workLogs = logs;
          _totalExpenses = expenses;
          _profit = (_order['total_price'] ?? 0) - expenses;
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

  // --- 1. ZAKAZNI TAHRIRLASH ---
  void _editOrderDialog() {
    final projectController = TextEditingController(text: _order['project_name']);
    final priceController = TextEditingController(text: _order['total_price'].toString());
    final areaController = TextEditingController(text: _order['total_area_m2'].toString());
    final notesController = TextEditingController(text: _order['notes'] ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zakazni Tahrirlash"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: projectController, decoration: const InputDecoration(labelText: "Loyiha nomi", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Summa (so'm)", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: areaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Kvadrat (m²)", border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: notesController, maxLines: 2, decoration: const InputDecoration(labelText: "Izoh", border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              try {
                await _supabase.from('orders').update({
                  'project_name': projectController.text,
                  'total_price': double.tryParse(priceController.text) ?? 0,
                  'total_area_m2': double.tryParse(areaController.text) ?? 0,
                  'notes': notesController.text,
                }).eq('id', widget.orderId);
                
                Navigator.pop(ctx);
                _loadOrderData(); // Yangilash
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz yangilandi!"), backgroundColor: Colors.green));
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

  // --- 2. STATUSNI O'ZGARTIRISH ---
  void _changeStatus() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(padding: EdgeInsets.all(15), child: Text("Jarayonni tanlang", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          _statusTile('pending', 'Kutilmoqda', Colors.orange),
          _statusTile('material', 'Material/Kesish', Colors.purple),
          _statusTile('assembly', 'Yig\'ish/Sex', Colors.blue),
          _statusTile('delivery', 'O\'rnatish/Yetkazish', Colors.teal),
          _statusTile('completed', 'Yakunlandi (Yopish)', Colors.green),
          _statusTile('canceled', 'Bekor qilindi', Colors.red),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _statusTile(String code, String label, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(label),
      trailing: _order['status'] == code ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () async {
        Navigator.pop(context);
        await _supabase.from('orders').update({'status': code}).eq('id', widget.orderId);
        _loadOrderData();
      },
    );
  }

  // --- 3. ZAKAZNI O'CHIRISH ---
  void _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zakazni o'chirish"),
        content: const Text("Rostdan ham bu zakazni va uning barcha tarixini o'chirmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA, O'CHIRILSIN", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('orders').delete().eq('id', widget.orderId);
      if (mounted) Navigator.pop(context); // Orqaga qaytish
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: Text(_order['order_number'] ?? "Zakaz"),
        actions: [
          IconButton(onPressed: _editOrderDialog, icon: const Icon(Icons.edit, color: Colors.blue)),
          IconButton(onPressed: _deleteOrder, icon: const Icon(Icons.delete, color: Colors.red)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STATUS VA ASOSIY INFO
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(_order['project_name'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                        InkWell(
                          onTap: _changeStatus,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(_order['status']).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _getStatusColor(_order['status']))
                            ),
                            child: Row(
                              children: [
                                Text(_getStatusText(_order['status']), style: TextStyle(color: _getStatusColor(_order['status']), fontWeight: FontWeight.bold)),
                                const Icon(Icons.arrow_drop_down, size: 18)
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                    const Divider(height: 20),
                    _infoRow(Icons.person, "Mijoz", _order['clients']?['full_name'] ?? "Noma'lum"),
                    _infoRow(Icons.phone, "Telefon", _order['clients']?['phone'] ?? "-"),
                    _infoRow(Icons.square_foot, "Hajm", "${_order['total_area_m2']} m²"),
                    if (_order['notes'] != null && _order['notes'].toString().isNotEmpty)
                      _infoRow(Icons.note, "Izoh", _order['notes']),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 15),

            // 2. MOLIYAVIY HISOBOT
            Row(
              children: [
                Expanded(child: _financeCard("Shartnoma", _order['total_price'], Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _financeCard("Xarajat (Ish haqi)", _totalExpenses, Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            Card(
              color: _profit >= 0 ? Colors.green.shade50 : Colors.red.shade50,
              child: ListTile(
                title: const Text("Joriy Sof Foyda"),
                trailing: Text(
                  "${_profit.toStringAsFixed(0)} so'm", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _profit >= 0 ? Colors.green.shade800 : Colors.red.shade800)
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Text("Jarayon Tarixi (Ishlar)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // 3. ISHLAR RO'YXATI (WORK LOGS)
            _workLogs.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Hozircha ishlar bajarilmagan")))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _workLogs.length,
                    itemBuilder: (ctx, i) {
                      final log = _workLogs[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text((log['profiles']?['full_name'] ?? "?").toString()[0]),
                          ),
                          title: Text(log['profiles']?['full_name'] ?? "Ishchi"),
                          subtitle: Text("${log['task_type']} - ${log['area_m2']} m²\n${log['description'] ?? ''}"),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("${log['total_sum']} so'm", style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(log['created_at'].toString().split('T')[0], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _financeCard(String title, dynamic amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 5),
          Text("${amount.toString()} so'm", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'material': return Colors.purple;
      case 'assembly': return Colors.blue;
      case 'delivery': return Colors.teal;
      case 'completed': return Colors.green;
      case 'canceled': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending': return 'Kutilmoqda';
      case 'material': return 'Kesish/Material';
      case 'assembly': return 'Yig\'ish';
      case 'delivery': return 'O\'rnatish';
      case 'completed': return 'Yakunlandi';
      case 'canceled': return 'Bekor qilindi';
      default: return status ?? '-';
    }
  }
}
