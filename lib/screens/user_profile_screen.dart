import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _earned = 0;
  double _withdrawn = 0;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    try {
      final logs = await _supabase.from('work_logs').select('total_sum').eq('worker_id', widget.user['id']).eq('is_approved', true);
      final draws = await _supabase.from('withdrawals').select('amount').eq('worker_id', widget.user['id']);

      double e = 0; double w = 0;
      for (var l in logs) e += (l['total_sum'] ?? 0).toDouble();
      for (var d in draws) w += (d['amount'] ?? 0).toDouble();

      setState(() {
        _earned = e; _withdrawn = w;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _TopPortion(user: widget.user),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        widget.user['full_name'] ?? "Noma'lum",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        (widget.user['role'] ?? "worker").toString().toUpperCase(),
                        style: TextStyle(color: Colors.grey.shade600, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 25),
                      
                      // Statistika qatori
                      _ProfileInfoRow(earned: _earned, withdrawn: _withdrawn),
                      
                      const SizedBox(height: 30),
                      
                      // Menyu tugmalari
                      _ProfileMenu(
                        text: "Ma'lumotlarni tahrirlash",
                        icon: Icons.edit_note_rounded,
                        color: Colors.blue,
                        press: () => _showEditDialog(),
                      ),
                      _ProfileMenu(
                        text: "Shaxsiy tariflar",
                        icon: Icons.payments_outlined,
                        color: Colors.green,
                        press: () {
                          // Tariflar mantiqi shu yerga keladi
                        },
                      ),
                      _ProfileMenu(
                        text: "Xavfsizlik va Parol",
                        icon: Icons.lock_reset_rounded,
                        color: Colors.orange,
                        press: () {},
                      ),
                      _ProfileMenu(
                        text: "Xodimni o'chirish",
                        icon: Icons.delete_forever_rounded,
                        color: Colors.red,
                        press: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // Tahrirlash dialogi
  void _showEditDialog() {
    final nameController = TextEditingController(text: widget.user['full_name']);
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('profiles').update({'full_name': nameController.text}).eq('id', widget.user['id']);
                Navigator.pop(context);
                _loadUserStats();
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

class _TopPortion extends StatelessWidget {
  final Map<String, dynamic> user;
  const _TopPortion({required this.user});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          height: 200, // Stack fit expand bo'lgani uchun balandlikni cheklaymiz
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.blue.shade900, Colors.blue.shade700],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(50),
                bottomRight: Radius.circular(50),
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
                color: Colors.grey.shade200,
              ),
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
          top: 40,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildInfoItem("Ishladi", earned, Colors.green),
          _buildVerticalDivider(),
          _buildInfoItem("Oldi", withdrawn, Colors.orange),
          _buildVerticalDivider(),
          _buildInfoItem("Qoldi", earned - withdrawn, Colors.blue.shade900),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 30, width: 1, color: Colors.grey.shade300);

  Widget _buildInfoItem(String title, double value, Color color) {
    return Column(
      children: [
        Text(value.toInt().toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
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