import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/main_wrapper.dart'; // Admin yoki User ekanini aniqlash uchun kerak bo'lishi mumkin

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Statistika
  double _myBalance = 0;
  double _earnedTotal = 0;
  double _paidTotal = 0;
  String _userName = "Foydalanuvchi";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Profil ma'lumotlari
      final profile = await _supabase.from('profiles').select().eq('id', user.id).single();
      
      // 2. Balans hisob-kitobi
      // Ishlagan pullari (work_logs)
      final worksRes = await _supabase
          .from('work_logs')
          .select('total_sum')
          .eq('worker_id', user.id);
      
      double earned = 0;
      for (var w in worksRes) {
        earned += (w['total_sum'] ?? 0).toDouble();
      }

      // Olgan pullari (transactions/withdrawals) - Agar sizda shunday jadval bo'lsa
      // Hozircha 0 deb turamiz yoki 'withdrawals' jadvalingiz bo'lsa o'shandan olamiz
      double paid = 0; 
      // Misol: final paidRes = await _supabase.from('withdrawals').select('amount').eq('user_id', user.id);
      
      if (mounted) {
        setState(() {
          _userName = profile['full_name'] ?? "Noma'lum";
          _earnedTotal = earned;
          _paidTotal = paid;
          _myBalance = earned - paid; // Balans formulasi
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- ISH TOPSHIRISH DIALOGI (TUZATILGAN) ---
  void _showWorkDialog() async {
    // 1. Ma'lumotlarni yuklash
    final ordersResp = await _supabase
        .from('orders')
        .select('*, clients(full_name)')
        .neq('status', 'completed') 
        .neq('status', 'canceled')
        .order('created_at', ascending: false);
        
    final taskTypesResp = await _supabase.from('task_types').select();

    if (!mounted) return;

    final orders = List<Map<String, dynamic>>.from(ordersResp);
    final taskTypes = List<Map<String, dynamic>>.from(taskTypesResp);

    dynamic selectedOrder;
    Map<String, dynamic>? selectedTask;
    final areaController = TextEditingController(); 
    final notesController = TextEditingController(); 
    double currentTotal = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Ish Topshirish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // 1. ZAKAZNI TANLASH
              DropdownButtonFormField<dynamic>(
                decoration: const InputDecoration(
                  labelText: "Qaysi zakazda ishladingiz?", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_shared)
                ),
                isExpanded: true,
                items: orders.map((o) => DropdownMenuItem<dynamic>(
                  value: o['id'], // ID ni saqlaymiz
                  child: Text("${o['project_name']} (${o['total_area_m2']} m²)", overflow: TextOverflow.ellipsis)
                )).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedOrder = v; // ID saqlandi
                    // Kvadratni topamiz
                    final fullOrder = orders.firstWhere((o) => o['id'] == v);
                    areaController.text = (fullOrder['total_area_m2'] ?? 0).toString();
                    
                    // Narxni yangilash
                    if (selectedTask != null) {
                       double area = double.tryParse(areaController.text) ?? 0;
                       currentTotal = area * (selectedTask!['default_rate'] ?? 0);
                    }
                  });
                },
              ),
              const SizedBox(height: 15),

              // 2. ISH TURINI TANLASH
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: const InputDecoration(labelText: "Nima ish qilindi?", border: OutlineInputBorder(), prefixIcon: Icon(Icons.handyman)),
                items: taskTypes.map((t) => DropdownMenuItem(value: t, child: Text("${t['name']}"))).toList(),
                onChanged: (v) {
                  setModalState(() {
                    selectedTask = v;
                    double area = double.tryParse(areaController.text) ?? 0;
                    currentTotal = area * (v?['default_rate'] ?? 0);
                  });
                },
              ),
              const SizedBox(height: 15),

              // 3. HAJM VA NARX
              TextField(
                controller: areaController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Hajm (m²)", border: OutlineInputBorder()),
                onChanged: (v) {
                  setModalState(() {
                    double area = double.tryParse(v) ?? 0;
                    currentTotal = area * (selectedTask?['default_rate'] ?? 0);
                  });
                },
              ),
              const SizedBox(height: 10),
              
              if (currentTotal > 0)
                 Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                   child: Row(
                     children: [
                       const Icon(Icons.monetization_on, color: Colors.green),
                       const SizedBox(width: 10),
                       Text("Tahminiy ish haqi: ${currentTotal.toInt()} so'm", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                     ],
                   ),
                 ),

              const SizedBox(height: 20),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (selectedOrder == null || selectedTask == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Zakaz va Ish turini tanlang!")));
                      return;
                    }
                    
                    try {
                      await _supabase.from('work_logs').insert({
                        'worker_id': _supabase.auth.currentUser!.id,
                        'order_id': selectedOrder, // ID
                        'task_type': selectedTask!['name'],
                        'area_m2': double.tryParse(areaController.text) ?? 0,
                        'rate': selectedTask!['default_rate'],
                        'total_sum': currentTotal,
                        'description': notesController.text,
                        'is_approved': false, 
                      });
                      
                      if (mounted) {
                        Navigator.pop(context);
                        _loadUserData(); // Balansni yangilash
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ish topshirildi!"), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      Navigator.pop(context); // Dialogni yopamiz xatoni ko'rish uchun
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
                  child: const Text("ISHNI TOPSHIRISH"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade900,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Column(
          children: [
            // Tepa qism (Balans)
            Container(
              padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Salom, $_userName", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                          const Text("Aristokrat Mebel", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Text(_userName.isNotEmpty ? _userName[0] : "A", style: const TextStyle(color: Colors.white)),
                      )
                    ],
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1), // To'q ko'k
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Mening shaxsiy balansim", style: TextStyle(color: Colors.white60)),
                        const SizedBox(height: 10),
                        Text("${_myBalance.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("↗ Ishladim", style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                  Text("${_earnedTotal.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: Colors.white24),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 15),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("↘ Oldim", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                    Text("${_paidTotal.toStringAsFixed(0)} so'm", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // Pastki qism (Oq fon)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // ISH TOPSHIRISH TUGMASI (KATTA)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: _showWorkDialog,
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text("ISH TOPSHIRISH", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade900,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Align(alignment: Alignment.centerLeft, child: Text("So'nggi harakatlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    // Bu yerga tarix qo'shish mumkin
                    const Expanded(child: Center(child: Text("Hozircha bo'sh", style: TextStyle(color: Colors.grey)))),
                  ],
                ),
              ),
            )
          ],
        ),
    );
  }
}