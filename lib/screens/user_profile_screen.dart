import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/reload_button.dart'; // Reload tugmasini import qilish

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Statistika o'zgaruvchilari
  double _earned = 0;
  double _withdrawn = 0;
  
  // Tariflar ro'yxati
  List<Map<String, dynamic>> _customRates = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // Barcha ma'lumotlarni (Statistika + Tariflar) bittada yuklash
  Future<void> _loadAllData() async {
    try {
      final userId = widget.user['id'];

      // Parallel so'rovlar (Tezlik uchun)
      final responses = await Future.wait([
        // 0. Ishlar summasi
        _supabase.from('work_logs').select('total_sum').eq('worker_id', userId).eq('is_approved', true),
        // 1. Olingan pullar
        _supabase.from('withdrawals').select('amount').eq('worker_id', userId),
        // 2. Barcha ish turlari
        _supabase.from('task_types').select(),
        // 3. Xodimning shaxsiy tariflari
        _supabase.from('user_rates').select().eq('user_id', userId),
      ]);

      // 1. Statistikani hisoblash
      final workLogs = responses[0] as List;
      final withdrawals = responses[1] as List;
      
      double e = 0; double w = 0;
      for (var log in workLogs) e += (log['total_sum'] ?? 0).toDouble();
      for (var draw in withdrawals) w += (draw['amount'] ?? 0).toDouble();

      // 2. Tariflarni birlashtirish (Merge)
      final allTasks = List<Map<String, dynamic>>.from(responses[2] as List);
      final userRates = List<Map<String, dynamic>>.from(responses[3] as List);

      List<Map<String, dynamic>> mergedRates = [];
      for (var task in allTasks) {
        // Xodim uchun maxsus narx bormi?
        final customRateObj = userRates.firstWhere(
          (r) => r['task_name'] == task['name'],
          orElse: () => <String, dynamic>{}, // Bo'sh map qaytaradi agar topilmasa
        );

        mergedRates.add({
          'name': task['name'],
          'default_rate': task['default_rate'],
          // Agar custom rate bo'lsa o'shani, bo'lmasa defaultni olamiz
          'current_rate': customRateObj.isNotEmpty ? customRateObj['custom_rate'] : task['default_rate'],
          'is_custom': customRateObj.isNotEmpty, // Maxsusmi yoki yo'qmi
        });
      }

      if (mounted) {
        setState(() {
          _earned = e;
          _withdrawn = w;
          _customRates = mergedRates;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Xatolik: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tarifni yangilash yoki qo'shish
  Future<void> _updateRate(String taskName, String newRateStr) async {
    double? newRate = double.tryParse(newRateStr);
    if (newRate == null) return;

    try {
      await _supabase.from('user_rates').upsert({
        'user_id': widget.user['id'],
        'task_name': taskName,
        'custom_rate': newRate,
      }, onConflict: 'user_id,task_name'); // Agar bor bo'lsa yangilaydi, yo'q bo'lsa qo'shadi

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif saqlandi!"), backgroundColor: Colors.green));
      _loadAllData(); // Ekranni yangilash
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e"), backgroundColor: Colors.red));
    }
  }

  // Xodimni o'chirish
  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Diqqat!"),
        content: const Text("Bu xodimni va uning barcha tarixini o'chirmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA, O'CHIRISH", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('profiles').delete().eq('id', widget.user['id']);
        if (mounted) {
          Navigator.pop(context); // Profil sahifasidan chiqish
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xodim o'chirildi")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 1. Header qismi (Reload tugmasi bilan)
          _TopPortion(
            user: widget.user,
            onRefresh: _loadAllData,
          ),
          
          // 2. Asosiy mazmun
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_isLoading) const LinearProgressIndicator(minHeight: 2, color: Colors.blue),
                  const SizedBox(height: 10),
                  
                  // Ism va Rol
                  Text(
                    widget.user['full_name'] ?? "Noma'lum",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      (widget.user['role'] ?? "worker").toString().toUpperCase(),
                      style: TextStyle(color: Colors.blue.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 25),
                  
                  // Statistika
                  _ProfileInfoRow(earned: _earned, withdrawn: _withdrawn),
                  
                  const SizedBox(height: 30),
                  
                  // --- MENYU TUGMALARI ---
                  
                  // 1. Tahrirlash
                  _ProfileMenu(
                    text: "Ma'lumotlarni tahrirlash",
                    icon: Icons.edit_note_rounded,
                    color: Colors.blue,
                    press: () => _showEditDialog(),
                  ),

                  // 2. Maxsus Tariflar
                  _ProfileMenu(
                    text: "Shaxsiy tariflar",
                    icon: Icons.attach_money_rounded,
                    color: Colors.green,
                    press: () => _showRatesDialog(),
                  ),

                  // 3. Xavfsizlik
                  _ProfileMenu(
                    text: "Parolni yangilash (Email)",
                    icon: Icons.lock_reset_rounded,
                    color: Colors.orange,
                    press: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emailga tiklash havolasi yuborildi (Imitasiya)")));
                      // Supabase'da: await _supabase.auth.resetPasswordForEmail(email);
                    },
                  ),

                  // 4. O'chirish
                  _ProfileMenu(
                    text: "Xodimni o'chirish",
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red,
                    press: _deleteUser,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tahrirlash Dialogi
  void _showEditDialog() {
    final nameController = TextEditingController(text: widget.user['full_name']);
    final phoneController = TextEditingController(text: widget.user['phone'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Ma'lumotlarni o'zgartirish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "F.I.SH", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Telefon", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('profiles').update({
                  'full_name': nameController.text,
                  'phone': phoneController.text
                }).eq('id', widget.user['id']);
                
                if (mounted) {
                  Navigator.pop(context);
                  _loadAllData();
                }
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade900),
              child: const Text("SAQLASH", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  // Tariflar Dialogi
  void _showRatesDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Shaxsiy Tariflar (so'm/m2)", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text("O'zgartirish uchun narxni yozib 'Enter' bosing", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _customRates.length,
                itemBuilder: (context, index) {
                  final item = _customRates[index];
                  final controller = TextEditingController(text: item['current_rate'].toString());
                  return ListTile(
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      item['is_custom'] ? "Maxsus narx" : "Standart narx (${item['default_rate']})",
                      style: TextStyle(color: item['is_custom'] ? Colors.green : Colors.grey, fontSize: 12),
                    ),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), border: OutlineInputBorder(), suffixText: "so'm"),
                        onSubmitted: (val) => _updateRate(item['name'], val),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- DIZAYN ELEMENTLARI (WIDGETLAR) ---

class _TopPortion extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onRefresh;

  const _TopPortion({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          alignment: Alignment.topCenter,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade900, Colors.blue.shade700],
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
            ),
          ),
        ),
        Positioned(
          top: 80, left: 0, right: 0,
          child: Center(
            child: Container(
              width: 130, height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5), color: Colors.grey.shade200),
              child: Center(
                child: Text(
                  (user['full_name'] ?? "?")[0].toUpperCase(),
                  style: TextStyle(fontSize: 50, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 40, left: 10,
          child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        ),
        // INCLUDE QILINGAN RELOAD TUGMASI
        Positioned(
          top: 40, right: 10,
          child: ReloadButton(onRefresh: onRefresh),
        )
      ],
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final double earned;
  final double withdrawn;
  const _ProfileInfoRow({required this.earned, required this.withdrawn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.grey.shade100)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem("Ishladi", earned, Colors.green),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          _buildInfoItem("Oldi", withdrawn, Colors.orange),
          Container(height: 40, width: 1, color: Colors.grey.shade300),
          _buildInfoItem("Balans", earned - withdrawn, Colors.blue.shade900),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, double value, Color color) {
    return Column(
      children: [
        Text(
          value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} '),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback press;

  const _ProfileMenu({required this.text, required this.icon, required this.color, required this.press});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: press,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}