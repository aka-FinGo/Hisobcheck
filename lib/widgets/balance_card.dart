import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';

class BalanceCard extends StatelessWidget {
  final String role; // 'boss', 'admin', yoki 'worker'
  
  // Asosiy ma'lumotlar
  final double mainBalance; 
  final double income; 
  final double expense; 
  
  // Orqa tomon (Back) uchun qo'shimcha ma'lumotlar
  final double? secondaryBalance; // Boshliq uchun qarzdorlik, worker uchun olingan summa
  final int? statsCount; // Worker uchun qilingan ishlar soni, boss uchun ishchilar soni

  const BalanceCard({
    super.key,
    required this.role,
    required this.mainBalance,
    required this.income,
    required this.expense,
    this.secondaryBalance,
    this.statsCount,
  });

  String _formatMoney(double amount) =>
      "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";

  @override
  Widget build(BuildContext context) {
    // GestureFlipCard barmog'i bilan bosganda aylanadi
    return GestureFlipCard(
      animationDuration: const Duration(milliseconds: 600),
      axis: FlipAxis.horizontal,
      frontWidget: _buildFrontSide(context),
      backWidget: _buildBackSide(context),
    );
  }

  // ─── KARTANING OLD TOMONI (FRONT) ─────────────────────────────
  Widget _buildFrontSide(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220, // Karta balandligi
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2980), Color(0xFF26D0CE)], // Premium Aristokrat gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2E5BFF).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tepa qism: Turi va Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                role == 'worker' ? "HODIM KARTASI" : "KORXONA KASSASI",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.memory, color: Colors.amberAccent, size: 32), // Chip ikonasi
            ],
          ),
          
          // O'rta qism: Asosiy Balans
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role == 'worker' ? "Mavjud Balansingiz" : "Umumiy Kassa (Sof foyda)",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
              const SizedBox(height: 5),
              Text(
                _formatMoney(mainBalance),
                style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
            ],
          ),

          // Pastki qism: Daromad va Xarajat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(
                label: role == 'worker' ? "Umumiy ishlangan" : "Daromad",
                value: _formatMoney(income),
                color: Colors.greenAccent,
              ),
              _buildMiniStat(
                label: role == 'worker' ? "Olingan (Avans)" : "Xarajatlar",
                value: _formatMoney(expense),
                color: Colors.redAccent.shade100,
                crossAxisAlignment: CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── KARTANING ORQA TOMONI (BACK) ─────────────────────────────
  Widget _buildBackSide(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B32B2), Color(0xFF1488CC)], // Orqasi sal to'qroq ko'k
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          // Magnit tasma (Qora chiziq)
          Container(
            width: double.infinity,
            height: 45,
            color: Colors.black87,
          ),
          const SizedBox(height: 20),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CVV maydoniga o'xshash statistika joyi
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getBackTitle1(),
                          style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatMoney(secondaryBalance ?? 0),
                          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // Qo'shimcha statistika (Ishchilar soni yoki reyting)
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _getBackTitle2(),
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${statsCount ?? 0}",
                        style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      const Text("ARISTOKRAT", style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Rolga qarab orqa tarafdagi yozuvlarni tanlash
  String _getBackTitle1() {
    switch (role) {
      case 'boss': return "ISHCHILARGA QARZDORLIK";
      case 'admin': return "SHAXSIY MAOSHINGIZ";
      case 'worker': return "KUTILAYOTGAN TO'LOV";
      default: return "QO'SHIMCHA MA'LUMOT";
    }
  }

  String _getBackTitle2() {
    switch (role) {
      case 'boss': return "Faol ishchilar";
      case 'admin': return "Bajarilgan ishlar";
      case 'worker': return "Joriy oylik reyting";
      default: return "Statistika";
    }
  }

  Widget _buildMiniStat({required String label, required String value, required Color color, CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.9), fontSize: 11)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
