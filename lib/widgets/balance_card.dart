import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';

class BalanceCard extends StatelessWidget {
  final String role;
  final double companyCash;    // Korxona kassasi
  final double workerDebt;     // Ishchilardan jami qarz
  final double personalEarned; // Shaxsiy topgan
  final double personalPaid;   // Shaxsiy olgan (avans)
  final int? statsCount;

  const BalanceCard({
    super.key,
    required this.role,
    required this.companyCash,
    required this.workerDebt,
    required this.personalEarned,
    required this.personalPaid,
    this.statsCount,
  });

  String _f(double a) => "${NumberFormat("#,###").format(a.abs()).replaceAll(',', ' ')} so'm";

  @override
  Widget build(BuildContext context) {
    return GestureFlipCard(
      axis: FlipAxis.horizontal,
      frontWidget: _buildFront(context),
      backWidget: _buildBack(context),
    );
  }

  Widget _buildFront(BuildContext context) {
    final theme = Theme.of(context);
    final isAUP = role == 'admin' || role == 'aup';
    final double mainBal = isAUP ? companyCash : (personalEarned - personalPaid);
    final isDebt = mainBal < 0;
    
    return _card(context, 
      isDebt && !isAUP ? [const Color(0xFFD31027), const Color(0xFFEA384D)] : [const Color(0xFF1E3C72), const Color(0xFF2A5298)],
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAUP ? "O'ZIMIZNIKI (KORXONA)" : (isDebt ? "SIZNING QARZINGIZ" : "OLISHIM KUTILYOTGAN HAQ (QOLDIQ)"), 
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text(_f(mainBal), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
        const Spacer(),
        _row(isAUP ? "Boshqalarga jami qarzlarimiz:" : "Shu oydagi jami hisoblangan:", _f(isAUP ? workerDebt : personalEarned)),
      ]));
  }

  Widget _buildBack(BuildContext context) {
    final isAUP = role == 'admin' || role == 'aup';
    return _card(context, [const Color(0xFF232526), const Color(0xFF414345)],
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(isAUP ? "SHAXSIY MAOSHIM" : "AVANSLAR VA ISHLAR", style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 10),
        Text(_f(personalEarned - personalPaid), style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
        const Divider(color: Colors.white24, height: 20),
        _row(isAUP ? "Men olgan avanslar:" : "Olingan avanslar:", _f(personalPaid)),
        const Spacer(),
        Text("ARISTOKRAT MEBEL", style: TextStyle(color: Colors.white.withOpacity(0.1), letterSpacing: 5, fontSize: 10)),
      ]));
  }

  Widget _card(BuildContext context, List<Color> colors, Widget child) {
    final isGlass = Theme.of(context).scaffoldBackgroundColor == Colors.transparent;
    return Container(
      height: 195, width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isGlass ? null : LinearGradient(colors: colors),
        color: isGlass ? Theme.of(context).cardTheme.color : null,
        border: isGlass ? Border.all(color: Colors.white24) : null,
      ),
      child: child,
    );
  }

  Widget _row(String t, String v) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(t, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  ]);
}
