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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Mening shaxsiy balansim", style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            "${balance.toStringAsFixed(0)} so'm",
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Ishladim", earned, Icons.trending_up, Colors.greenAccent),
              _miniStat("Oldim", withdrawn, Icons.trending_down, Colors.orangeAccent),
            ],
          ),
          // Admin yoki Owner uchun maxsus tugma
          if (role == 'admin' || role == 'owner') ...[
            const Divider(color: Colors.white24, height: 25),
            InkWell(
              onTap: onStatsTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.analytics, color: Colors.amber, size: 18),
                  SizedBox(width: 8),
                  Text("Sex umumiy statistikasi", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
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
        Text(val.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
