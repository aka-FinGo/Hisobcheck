import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddWorkLogScreen extends StatefulWidget {
  const AddWorkLogScreen({super.key});
  @override
  State<AddWorkLogScreen> createState() => _AddWorkLogScreenState();
}

class _AddWorkLogScreenState extends State<AddWorkLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSubmitting = false;

  List<dynamic> _activeOrders = [];
  Map<String, dynamic>? _myProfile;
  
  int? _selectedOrderId;
  double _maxLimit = 0; // Buyurtmaning umumiy hajmi (Limit)
  String _unitLabel = "m2"; // dona, metr, m2
  
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Profil va Role'dan o'lchov birligini olish
      final profile = await _supabase
          .from('profiles')
          .select('*, app_roles!profiles_position_id_fkey(*)')
          .eq('id', userId)
          .single();
      
      // 2. Aktiv zakazlarni va ularning kvadratini olish
      final orders = await _supabase
          .from('orders')
          .select('id, order_number, project_name, total_area_m2')
          .inFilter('status', ['pending', 'material', 'assembly', 'delivery'])
          .order('created_at', ascending: false);

      setState(() {
        _myProfile = profile;
        _activeOrders = orders;
        _unitLabel = profile['custom_unit_type'] ?? profile['app_roles']?['unit_type'] ?? "m2";
      });
    } catch (e) {
      debugPrint("Xato: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ZAKAZ TANLANGANDA LIMITNI O'RNATISH VA INPUTNI TO'LDIRISH
  void _onOrderSelected(int? orderId) {
    if (orderId == null) return;
    
    final selectedOrder = _activeOrders.firstWhere((o) => o['id'] == orderId);
    final totalArea = (selectedOrder['total_area_m2'] ?? 0).toDouble();

    setState(() {
      _selectedOrderId = orderId;
      _maxLimit = totalArea;
      // Avtomatik maksimal qiymatni yozib qo'yamiz
      _amountCtrl.text = totalArea.toString();
    });
  }
Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;

    // --- SENIORCHA VALIDATSIYA ---
    if (_selectedOrderId == null) {
      _msg("Iltimos, buyurtmani tanlang!", Colors.red);
      return;
    }
    if (amount <= 0) {
      _msg("Miqdorni kiriting!", Colors.red);
      return;
    }
    if (amount > _maxLimit) {
      _msg("Xato! Buyurtma hajmi $_maxLimit $_unitLabel. Siz $amount kiritdingiz!", Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final role = _myProfile?['app_roles'];
      final rate = (_myProfile?['custom_rate_per_unit'] ?? role?['rate_per_unit'] ?? 0).toDouble();

      final res = await _supabase.from('work_logs').insert({
        'worker_id': _supabase.auth.currentUser!.id,
        'order_id': _selectedOrderId,
        'task_type': role?['name'] ?? "Ish",
        'area_m2': amount, // m2 bo'lsa ham, dona bo'lsa ham shu ustunga yoziladi
        'rate': rate,
        'description': _descCtrl.text.trim(),
        'is_approved': false,
      }).select().single();
      
      // Adminlarga bildirishnoma yuborish
      final admins = await _supabase.from('profiles').select('id').eq('is_super_admin', true);
      for (var a in admins) {
        await _supabase.from('notifications').insert({
          'user_id': a['id'],
          'title': 'Yangi Ish Topshirildi',
          'body': '${_myProfile?['full_name'] ?? 'Hodim'} yangi ish topshirdi. Obyom: $amount $_unitLabel',
          'type': 'work_log',
          'target_id': res['id'].toString(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        _msg("Ish muvaffaqiyatli topshirildi!", Colors.green);
      }
    } catch (e) {
      _msg("Xatolik: $e", Colors.red);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _msg(String txt, Color cls) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt), backgroundColor: cls));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ish Topshirish")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Buyurtmani tanlang", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _selectedOrderId,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: _activeOrders.map((o) => DropdownMenuItem<int>(
                    value: o['id'], 
                    child: Text("${o['order_number']} (${o['project_name']})")
                  )).toList(),
                  onChanged: _onOrderSelected,
                ),
                const SizedBox(height: 25),
                Text("Bajarilgan miqdor ($_unitLabel)", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: "0.0",
                    helperText: _selectedOrderId != null ? "Maksimal limit: $_maxLimit $_unitLabel" : null,
                    helperStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 25),
                const Text("Izoh", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Ish haqida qo'shimcha ma'lumot...")),
                const SizedBox(height: 35),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("TOPSHIRISH", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
