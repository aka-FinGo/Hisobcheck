import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';

class BalanceCard extends StatelessWidget {
  final String role; // 'admin', 'aup', 'worker'
  
  // --- KORHONA MA'LUMOTLARI (Admin/AUP uchun) ---
  final double companyBalance; 
  final double totalWorkerDebt; // Ishchilarga berilishi kerak bo'lgan jami qarz
  
  // --- SHAXSIY MA'LUMOTLAR (Hamma uchun) ---
  final double personalEarnings; // Ishlab topgan maoshi
  final double personalAdvances; // Olgan avanslari
  final int? statsCount;

  const BalanceCard({
    super.key,
    required this.role,
    required this.companyBalance,
    required this.totalWorkerDebt,
    required this.personalEarnings,
    required this.personalAdvances,
    this.statsCount,
  });

  String _formatMoney(double amount) {
    // Minus qiymatni musbat qilib ko'rsatish (yozuvda "Qarz" deymiz)
    final absAmount = amount.abs();
    return "${NumberFormat("#,###").format(absAmount).replaceAll(',', ' ')} so'm";
  }

  @override
  Widget build(BuildContext context) {
    return GestureFlipCard(
      animationDuration: const Duration(milliseconds: 600),
      axis: FlipAxis.horizontal,
      frontWidget: _buildFrontSide(context),
      backWidget: _buildBackSide(context),
    );
  }

  // OLD TOMON: Admin uchun Korhona, Worker uchun Shaxsiy balans
  Widget _buildFrontSide(BuildContext context) {
    final theme = Theme.of(context);
    final isAUP = role == 'admin' || role == 'aup';
    
    // Mantiq: Admin bo'lsa korhona kassasi, ishchi bo'lsa o'z puli
    final double mainValue = isAUP ? companyBalance : (personalEarnings - personalAdvances);
    final String label = isAUP 
        ? "KORXONA KASSASI" 
        : (mainValue < 0 ? "SIZNING QARZINGIZ" : "MAVJUD BALANSINGIZ");

    return _baseCard(
      context,
      gradient: isAUP 
        ? const LinearGradient(colors: [Color(0xFF1E3C72), Color(0xFF2A5298)]) 
        : (mainValue < 0 
            ? const LinearGradient(colors: [Color(0xFFD31027), Color(0xFFEA384D)]) // Qarz bo'lsa qizil
            : const LinearGradient(colors: [Color(0xFF00B4DB), Color(0xFF0083B0)])),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white54),
            ],
          ),
          const SizedBox(height: 15),
          Text(_formatMoney(mainValue), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const Spacer(),
          if (isAUP) ...[
            _miniStat("Ishchilarga qarz:", _formatMoney(totalWorkerDebt), Colors.orangeAccent),
          ] else ...[
            _miniStat("Jami ish haqi:", _formatMoney(personalEarnings), Colors.white),
          ],
        ],
      ),
    );
  }
// ORQA TOMON: Admin o'zining shaxsiy maoshini ko'radi
  Widget _buildBackSide(BuildContext context) {
    final theme = Theme.of(context);
    final isAUP = role == 'admin' || role == 'aup';
    
    // Shaxsiy balans hisobi
    final double myBalance = personalEarnings - personalAdvances;
    final String backLabel = isAUP ? "SHAXSIY HISOBINGIZ" : "STATISTIKA";

    return _baseCard(
      context,
      gradient: const LinearGradient(colors: [Color(0xFF232526), Color(0xFF414345)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(backLabel, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(_formatMoney(myBalance), style: const TextStyle(color: Colors.amberAccent, fontSize: 24, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white10, height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _miniStat("Olingan avans:", _formatMoney(personalAdvances), Colors.redAccent),
              if (statsCount != null)
                _miniStat(isAUP ? "Buyurtmalar:" : "Ishlar soni:", "$statsCount ta", Colors.blueAccent, align: CrossAxisAlignment.end),
            ],
          ),
          const Spacer(),
          const Text("ARISTOKRAT MEBEL", style: TextStyle(color: Colors.white12, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 5)),
        ],
      ),
    );
  }

  // --- ASOSIY DIZAYN QOLIBI (3-Theme qo'llab quvvatlaydi) ---
  Widget _baseCard(BuildContext context, {required Gradient gradient, required Widget child}) {
    final theme = Theme.of(context);
    final isGlass = theme.scaffoldBackgroundColor == Colors.transparent;

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: isGlass ? null : gradient,
        color: isGlass ? theme.cardTheme.color : null,
        border: isGlass ? Border.all(color: Colors.white.withOpacity(0.2)) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(25),
      child: child,
    );
  }

  Widget _miniStat(String label, String value, Color color, {CrossAxisAlignment align = CrossAxisAlignment.start}) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}