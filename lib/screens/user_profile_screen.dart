import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/reload_button.dart';
import 'login_screen.dart'; // Chiqish uchun kerak
import 'admin_panel_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user; // Kimning profili ko'rilyapti?
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Statistika
  double _earned = 0;
  double _withdrawn = 0;
  
  // Tariflar
  List<Map<String, dynamic>> _customRates = [];
  
  // Rol va Huquqlar
  String _myRole = 'worker'; // Mening rolim
  String _myId = '';         // Mening ID im
  bool _amIAdmin = false;    // Men Adminmanmi?
  bool _amIOwner = false;    // Men Xo'jayinmanmi?
  bool _isMe = false;        // Bu mening profilimmi?

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoad();
  }

  Future<void> _checkPermissionsAndLoad() async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      _myId = currentUser.id;
      _isMe = _myId == widget.user['id'];

      // Mening rolimni aniqlash
      final myProfile = await _supabase.from('profiles').select('role').eq('id', _myId).single();
      _myRole = myProfile['role'] ?? 'worker';
      _amIOwner = _myRole == 'owner';
      _amIAdmin = _myRole == 'admin' || _amIOwner;
    }
    
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final userId = widget.user['id'];

      final responses = await Future.wait([
        _supabase.from('work_logs').select('total_sum').eq('worker_id', userId).eq('is_approved', true),
        _supabase.from('withdrawals').select('amount').eq('worker_id', userId),
        _supabase.from('task_types').select(),
        _supabase.from('user_rates').select().eq('user_id', userId),
      ]);

      // Statistika
      double e = 0; double w = 0;
      for (var log in (responses[0] as List)) e += (log['total_sum'] ?? 0).toDouble();
      for (var draw in (responses[1] as List)) w += (draw['amount'] ?? 0).toDouble();

      // Tariflar
      final allTasks = List<Map<String, dynamic>>.from(responses[2] as List);
      final userRates = List<Map<String, dynamic>>.from(responses[3] as List);

      List<Map<String, dynamic>> mergedRates = [];
      for (var task in allTasks) {
        final customRateObj = userRates.firstWhere(
          (r) => r['task_name'] == task['name'],
          orElse: () => <String, dynamic>{},
        );
        mergedRates.add({
          'name': task['name'],
          'default_rate': task['default_rate'],
          'current_rate': customRateObj.isNotEmpty ? customRateObj['custom_rate'] : task['default_rate'],
          'is_custom': customRateObj.isNotEmpty,
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNKSIYALAR ---

  // 1. Tarixni ko'rish
  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _HistorySheet(userId: widget.user['id']),
    );
  }

  // 2. Admin: Tarifni o'zgartirish
  Future<void> _updateRate(String taskName, String newRateStr) async {
    double? newRate = double.tryParse(newRateStr);
    if (newRate == null) return;
    try {
      await _supabase.from('user_rates').upsert({
        'user_id': widget.user['id'],
        'task_name': taskName,
        'custom_rate': newRate,
      }, onConflict: 'user_id,task_name');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tarif saqlandi!"), backgroundColor: Colors.green));
      _loadAllData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
    }
  }

  // 3. Admin: Xodim Login/Emailini o'zgartirish (Auth emas, Profile dagi ma'lumot)
  // Eslatma: Supabase Auth emailini client-side o'zgartirish uchun user o'zi kirgan bo'lishi kerak.
  // Admin faqat "Parol tiklash" xatini yubora oladi.
  void _showAdminEditAuth() {
    final emailController = TextEditingController(text: widget.user['email'] ?? 'Email yo\'q');
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Login va Parol boshqaruvi"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Diqqat! Xavfsizlik sababli parolni to'g'ridan-to'g'ri ko'ra olmaysiz.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: "Yangi Email (Login)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                // Admin xodimga parol tiklash xatini yuboradi
                try {
                  // Agar email bo'lsa
                  if (emailController.text.contains('@')) {
                     await _supabase.auth.resetPasswordForEmail(emailController.text);
                     if (mounted) {
                       Navigator.pop(ctx);
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parol tiklash havolasi emailga yuborildi!"), backgroundColor: Colors.green));
                     }
                  } else {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email noto'g'ri")));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                }
              }, 
              icon: const Icon(Icons.lock_reset),
              label: const Text("Parol tiklash xatini yuborish"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("YOPISH")),
        ],
      ),
    );
  }

  // 4. O'zimni parolimni yangilash
  void _showChangeMyPassword() {
    final passController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Parolni yangilash"),
        content: TextField(
          controller: passController,
          decoration: const InputDecoration(labelText: "Yangi parol", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("BEKOR")),
          ElevatedButton(
            onPressed: () async {
              if (passController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parol kamida 6 ta belgi bo'lishi kerak")));
                return;
              }
              try {
                await _supabase.auth.updateUser(UserAttributes(password: passController.text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Parol muvaffaqiyatli o'zgartirildi!"), backgroundColor: Colors.green));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
              }
            }, 
            child: const Text("SAQLASH")
          ),
        ],
      ),
    );
  }

  // 5. O'chirish (Faqat Owner)
  Future<void> _deleteUser() async {
    if (_isMe) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Siz o'zingizni o'chira olmaysiz!")));
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("DIQQAT!"),
        content: const Text("Xodimni o'chirsangiz, uning barcha ish tarixi va hisob-kitoblari o'chib ketishi mumkin. Tasdiqlaysizmi?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("YO'Q")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("HA, O'CHIRISH", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Supabase Edge Function bo'lmasa, clientdan turib auth user o'chirish qiyin.
        // Hozircha profilni o'chiramiz.
        await _supabase.from('profiles').delete().eq('id', widget.user['id']);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Xodim tizimdan o'chirildi")));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
      }
    }
  }

  // 6. Chiqish (Logout)
  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // HEADER (Chiqish tugmasisiz)
          _TopPortion(user: widget.user, onRefresh: _loadAllData),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
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
                      _ProfileInfoRow(earned: _earned, withdrawn: _withdrawn),
                      const SizedBox(height: 30),
                      
                      // --- UMUMIY MENYU ---
                      _ProfileMenu(
                        text: "Ish tarixi (Tarix)",
                        icon: Icons.history,
                        color: Colors.indigo,
                        press: _showHistory,
                      ),

                      // Agar o'zim bo'lsam -> Parolni o'zgartirish
                      if (_isMe)
                        _ProfileMenu(
                          text: "Parolni o'zgartirish",
                          icon: Icons.key,
                          color: Colors.blue,
                          press: _showChangeMyPassword,
                        ),

                      // --- ADMIN SOZLAMALARI (Faqat Admin/Owner ko'radi) ---
                      if (_amIAdmin && !_isMe) ...[
                        const SizedBox(height: 20),
                        const Align(alignment: Alignment.centerLeft, child: Text(" ADMIN SOZLAMALARI", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12))),
                        const SizedBox(height: 10),
                        
                        _ProfileMenu(
                          text: "Shaxsiy tariflar",
                          icon: Icons.attach_money,
                          color: Colors.green,
                          press: () => _showRatesDialog(),
                        ),
                        _ProfileMenu(
                          text: "Login va Parol (Email)",
                          icon: Icons.admin_panel_settings,
                          color: Colors.orange,
                          press: _showAdminEditAuth,
                        ),
                      ],

                      // --- O'CHIRISH (Faqat Owner va o'zi emas) ---
                      if (_amIOwner && !_isMe) ...[
                         const SizedBox(height: 10),
                        _ProfileMenu(
                          text: "Xodimni o'chirish",
                          icon: Icons.delete_forever,
                          color: Colors.red,
                          press: _deleteUser,
                        ),
                      ],

                      const SizedBox(height: 40),

                      // --- CHIQISH TUGMASI (ENG PASTDA) ---
                      if (_isMe) 
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text("PROFILDAN CHIQISH"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              foregroundColor: Colors.red,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 15)
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // Tariflar Dialogi UI
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
            const Text("Shaxsiy Tariflar", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _customRates.length,
                itemBuilder: (context, index) {
                  final item = _customRates[index];
                  final controller = TextEditingController(text: item['current_rate'].toString());
                  return ListTile(
                    title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['is_custom'] ? "Maxsus" : "Standart", style: TextStyle(color: item['is_custom'] ? Colors.green : Colors.grey)),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10), border: OutlineInputBorder(), suffixText: "so'm"),
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

// --- TARIX VARAQASI (HISTORY SHEET) ---
class _HistorySheet extends StatefulWidget {
  final String userId;
  const _HistorySheet({required this.userId});

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _supabase.from('work_logs')
        .select('*, orders(order_number)')
        .eq('worker_id', widget.userId)
        .order('created_at', ascending: false)
        .limit(50); // Oxirgi 50 ta ish
    
    if (mounted) setState(() { _logs = List<Map<String, dynamic>>.from(data); _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          const Text("Ish Tarixi (Oxirgi 50 ta)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty 
                  ? const Center(child: Text("Hali ishlar yo'q"))
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) {
                        final item = _logs[i];
                        final date = item['created_at'].toString().substring(0, 10);
                        return ListTile(
                          leading: Icon(item['is_approved'] ? Icons.check_circle : Icons.access_time, color: item['is_approved'] ? Colors.green : Colors.orange),
                          title: Text("${item['task_type']} - ${item['area_m2']} m2"),
                          subtitle: Text("Zakaz: ${item['orders']?['order_number'] ?? '-'} | $date"),
                          trailing: Text("${item['total_sum']} so'm", style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
          )
        ],
      ),
    );
  }
}

// --- UI WIDGETLAR (O'zgarishsiz qoldi) ---

class _TopPortion extends StatelessWidget {
  final Map<String, dynamic> user;
  final Future<void> Function() onRefresh;
  const _TopPortion({required this.user, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade700]),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
        ),
        Positioned(
          top: 60, left: 0, right: 0,
          child: Center(
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.grey.shade200),
              child: Center(child: Text((user['full_name'] ?? "?")[0].toUpperCase(), style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue.shade900))),
            ),
          ),
        ),
        Positioned(top: 40, left: 10, child: BackButton(color: Colors.white)), // Agar main_wrapperda bo'lsa bu kerak bo'lmasligi mumkin, lekin tursa ziyoni yo'q
        Positioned(top: 40, right: 10, child: ReloadButton(onRefresh: onRefresh)),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _stat("Ishladi", earned, Colors.green),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _stat("Oldi", withdrawn, Colors.orange),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _stat("Qoldi", earned - withdrawn, Colors.blue.shade900),
        ],
      ),
    );
  }
  Widget _stat(String l, double v, Color c) => Column(children: [Text("${v.toInt()}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c)), Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey))]);
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: press,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [Icon(icon, color: color), const SizedBox(width: 20), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right, color: Colors.grey)]),
        ),
      ),
    );
  }
}