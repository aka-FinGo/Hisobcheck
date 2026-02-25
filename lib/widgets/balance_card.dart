import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BalanceCard extends StatelessWidget {
  final bool isAdmin;
  final double earned;
  final double withdrawn;

  const BalanceCard({
    super.key,
    required this.isAdmin,
    required this.earned,
    required this.withdrawn,
  });

  String _formatMoney(double amount) =>
      "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";

  @override
  Widget build(BuildContext context) {
    final double balance = earned - withdrawn;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF2E5BFF), Color(0xFF6C3FE8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2E5BFF).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isAdmin ? "Jami aylanma (Daromad)" : "Ishlangan mablag'", 
                     style: const TextStyle(color: Colors.white70, fontSize: 14)),
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
              ],
            ),
            const SizedBox(height: 10),
            Text(_formatMoney(earned), 
                 style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BalanceRow(
                    label: isAdmin ? "Xarajatlar" : "Olingan",
                    value: _formatMoney(withdrawn),
                    icon: Icons.arrow_upward_rounded,
                    color: Colors.redAccent.shade100,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white.withOpacity(0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _BalanceRow(
                      label: isAdmin ? "Sof Foyda" : "Qoldiq",
                      value: _formatMoney(balance),
                      icon: Icons.savings_outlined,
                      color: Colors.greenAccent.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceRow({
    required this.label, required this.value, required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
