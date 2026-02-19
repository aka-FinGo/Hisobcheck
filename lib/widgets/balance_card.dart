import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double earned;
  final double withdrawn;
  final String role;
  final VoidCallback onStatsTap;

  const BalanceCard({
    super.key,
    required this.earned,
    required this.withdrawn,
    required this.role,
    required this.onStatsTap,
  });

  @override
  Widget build(BuildContext context) {
    double balance = earned - withdrawn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mening shaxsiy balansim", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 5),
          // Animatsiyali Asosiy Balans
          AnimatedCounter(
            value: balance, 
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Ishladim", earned, Icons.trending_up, Colors.greenAccent),
              Container(width: 1, height: 40, color: Colors.white24), // O'rtadagi chiziq
              _miniStat("Oldim", withdrawn, Icons.trending_down, Colors.orangeAccent),
            ],
          ),
          if (role == 'admin' || role == 'owner') ...[
            const Divider(color: Colors.white24, height: 30),
            InkWell(
              onTap: onStatsTap,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.analytics, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text("Umumiy statistikasi", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                  Icon(Icons.chevron_right, color: Colors.amber),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, double val, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        // Kichik raqamlar ham animatsiya bilan
        AnimatedCounter(
          value: val, 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}

// ANIMATSIYA QILUVCHI MAXSUS VIDJET
class AnimatedCounter extends StatelessWidget {
  final double value;
  final TextStyle style;

  const AnimatedCounter({super.key, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(seconds: 1), // 1 soniya davomida o'zgaradi
      curve: Curves.easeOutExpo, // Tez boshlanib, sekin to'xtaydi
      builder: (context, val, child) {
        return Text(
          "${val.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} so'm",
          style: style,
        );
      },
    );
  }
}
