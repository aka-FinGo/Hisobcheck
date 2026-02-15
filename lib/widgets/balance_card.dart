import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double earned;
  final double withdrawn;

  const BalanceCard({
    super.key,
    required this.earned,
    required this.withdrawn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade900, Colors.blue.shade600]
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Olinishi kerak bo'lgan haq (Balans)", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Text(
            "${(earned - withdrawn).toStringAsFixed(0)} so'm",
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1)
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, color: Colors.greenAccent.shade100, size: 16),
                      const SizedBox(width: 5),
                      const Text("Jami Ishlandi", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${earned.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Text("Jami Olindi", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 5),
                      Icon(Icons.arrow_downward, color: Colors.orangeAccent.shade100, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${withdrawn.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
