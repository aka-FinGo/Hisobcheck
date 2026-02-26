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

  // Ma'lumotlar
  List<dynamic> _activeOrders = [];
  List<dynamic> _taskTypes = [];
  Map<String, dynamic>? _myProfile;
  
  // Form boshqaruvi
  int? _selectedOrderId;
  String? _selectedTaskType; // 'my_role' yoki task_types jadvalidagi ID
  
  // Kiritish maydonlari
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Hisoblangan ma'lumotlar
  double _currentRate = 0;
  String _currentUnit = 'dona';
  String _taskNameForLog = '';
  String? _targetStatusForAutoMove;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Mening profilim va Lavozimim (Stavka, Birlik)
      final profileRes = await _supabase
          .from('profiles')
          .select('*, app_roles(*)')
          .eq('id', userId)
          .single();
          
      // 2. Aktiv zakazlar (Kutilmoqda, Kesish, Yig'ish, O'rnatish)
      final ordersRes = await _supabase
          .from('orders')
          .select('id, order_number, client_name, project_name')
          .inFilter('status', ['pending', 'material', 'assembly', 'delivery'])
          .order('created_at', ascending: false);

      // 3. Umumiy Tariflar (Boshqa ishlar uchun)
      final tasksRes = await _supabase.from('task_types').select().order('name');

      setState(() {
        _myProfile = profileRes;
        _activeOrders = ordersRes;
        _taskTypes = tasksRes;
        
        // Avtomatik ravishda o'z lavozimini tanlab qo'yish
        _selectedTaskType = 'my_role';
        _updateRateAndUnit();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yuklashda xato: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tanlangan ish turiga qarab narx va o'lchovni yangilash
  void _updateRateAndUnit() {
    if (_selectedTaskType == 'my_role') {
      final role = _myProfile?['app_roles'];
      _currentRate = (_myProfile?['custom_rate_per_unit'] ?? role?['rate_per_unit'] ?? 0).toDouble();
      _currentUnit = _myProfile?['custom_unit_type'] ?? role?['unit_type'] ?? 'dona';
      _taskNameForLog = role?['name'] ?? 'Asosiy vazifa';
      _targetStatusForAutoMove = role?['target_status'];
    } else {
      // Tariflardan (task_types) qidirish
      final selectedTask = _taskTypes.firstWhere((t) => t['id'].toString() == _selectedTaskType, orElse: () => null);
      if (selectedTask != null) {
        _currentRate = (selectedTask['price_per_unit'] ?? 0).toDouble();
        _currentUnit = selectedTask['unit'] ?? 'dona';
        _taskNameForLog = selectedTask['name'];
        _targetStatusForAutoMove = selectedTask['target_status'];
      }
    }
    // Miqdor o'zgarganda UI ni yangilash uchun
    setState(() {});
  }

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

  // Ma'lumotlar
  List<dynamic> _activeOrders = [];
  List<dynamic> _taskTypes = [];
  Map<String, dynamic>? _myProfile;
  
  // Form boshqaruvi
  int? _selectedOrderId;
  String? _selectedTaskType; 
  
  // Kiritish maydonlari
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Hisoblangan ma'lumotlar
  double _currentRate = 0;
  String _currentUnit = 'dona';
  String _taskNameForLog = '';
  String? _targetStatusForAutoMove;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      final profileRes = await _supabase
          .from('profiles')
          .select('*, app_roles(*)')
          .eq('id', userId)
          .single();
          
      final ordersRes = await _supabase
          .from('orders')
          .select('id, order_number, client_name, project_name')
          .inFilter('status', ['pending', 'material', 'assembly', 'delivery'])
          .order('created_at', ascending: false);

      final tasksRes = await _supabase.from('task_types').select().order('name');

      setState(() {
        _myProfile = profileRes;
        _activeOrders = ordersRes;
        _taskTypes = tasksRes;
        
        _selectedTaskType = 'my_role';
        _updateRateAndUnit();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yuklashda xato: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateRateAndUnit() {
    if (_selectedTaskType == 'my_role') {
      final role = _myProfile?['app_roles'];
      _currentRate = (_myProfile?['custom_rate_per_unit'] ?? role?['rate_per_unit'] ?? 0).toDouble();
      _currentUnit = _myProfile?['custom_unit_type'] ?? role?['unit_type'] ?? 'dona';
      _taskNameForLog = role?['name'] ?? 'Asosiy vazifa';
      _targetStatusForAutoMove = role?['target_status'];
    } else {
      final selectedTask = _taskTypes.firstWhere((t) => t['id'].toString() == _selectedTaskType, orElse: () => null);
      if (selectedTask != null) {
        _currentRate = (selectedTask['price_per_unit'] ?? 0).toDouble();
        _currentUnit = selectedTask['unit'] ?? 'dona';
        _taskNameForLog = selectedTask['name'];
        _targetStatusForAutoMove = selectedTask['target_status'];
      }
    }
    setState(() {});
  }

  // Jami summani hisoblash
  double get _calculatedTotal {
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    return amount * _currentRate;
  }

  Future<void> _submitWorkLog() async {
    if (_selectedOrderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Iltimos, zakazni tanlang!"), backgroundColor: Colors.red));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Miqdorni to'g'ri kiriting!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // 1. Work Log (Ish hisoboti) ga yozamiz
      await _supabase.from('work_logs').insert({
        'worker_id': _supabase.auth.currentUser!.id,
        'order_id': _selectedOrderId,
        'task_type': _taskNameForLog,
        'area_m2': amount, // Bu maydonni bazada keyinroq 'quantity' deb o'zgartirgan ma'qul, hozircha ishlayveradi
        'rate': _currentRate,
        'total_sum': _calculatedTotal,
        'description': _descCtrl.text.trim(),
        'is_approved': false, // Rahbar tasdiqlashi kerak
      });

      // 2. AVTOMATIZATSIYA (Agar bu ish bajarilganda zakaz statusi o'zgarishi kerak bo'lsa)
      if (_targetStatusForAutoMove != null) {
        await _supabase.from('orders').update({
          'status': _targetStatusForAutoMove
        }).eq('id', _selectedOrderId!);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish muvaffaqiyatli topshirildi! Rahbar tasdig'i kutilmoqda."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ish topshirish"), elevation: 0),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. ZAKAZ TANLASH
                const Text("Qaysi zakaz?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _selectedOrderId,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Zakazni tanlang..."),
                  items: _activeOrders.map((o) => DropdownMenuItem<int>(
                    value: o['id'], 
                    child: Text("${o['order_number']} - ${o['client_name']}")
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedOrderId = val),
                ),
                const SizedBox(height: 25),

                // 2. ISH TURINI TANLASH
                const Text("Nima ish qildingiz?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedTaskType,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [
                    DropdownMenuItem(
                      value: 'my_role', 
                      child: Text("O'z vazifam (${_myProfile?['app_roles']?['name'] ?? 'Asosiy'})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))
                    ),
                    const DropdownMenuItem(value: '', enabled: false, child: Divider()), // Ajratuvchi chiziq
                    ..._taskTypes.map((t) => DropdownMenuItem(
                      value: t['id'].toString(), 
                      child: Text(t['name'])
                    )).toList(),
                  ],
                  onChanged: (val) {
                    if (val != null && val.isNotEmpty) {
                      setState(() => _selectedTaskType = val);
                      _updateRateAndUnit();
                    }
                  },
                ),
                const SizedBox(height: 25),

                // 3. MIQDOR KIRITISH VA KALKULYATOR
                const Text("Miqdor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: "0.0",
                          suffixText: _currentUnit, // dona, m2, m
                        ),
                        onChanged: (val) => setState(() {}), // Yozgan sari pulni hisoblab turadi
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("Stavka: ${NumberFormat("#,###").format(_currentRate)} / $_currentUnit", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 5),
                          Text(
                            "${NumberFormat("#,###").format(_calculatedTotal)} so'm", 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),

                // 4. QO'SHIMCHA IZOH
                const Text("Izoh (ixtiyoriy)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Masalan: Qiyinroq burchak edi..."),
                ),
                const SizedBox(height: 40),

                // 5. YUBORISH TUGMASI
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E5BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isSubmitting ? null : _submitWorkLog,
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Ishni Topsirish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
    );
  }
}
