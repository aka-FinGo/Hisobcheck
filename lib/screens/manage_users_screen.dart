import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  List<dynamic> _users = [];
  List<dynamic> _roles = []; // Bazadagi lavozimlar ro'yxati

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // BAZADAN XODIMLAR VA LAVOZIMLARNI BIRGALIKDA TORTIB KELAMIZ
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Lavozimlarni yuklash (Dropdown uchun)
      final rolesRes = await _supabase.from('app_roles').select().order('name');
      
      // 2. Xodimlarni yuklash (Lavozim ma'lumotlari bilan birga)
      final usersRes = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type, base_salary, bonus_per_m2)')
          .order('created_at');

      setState(() {
        _roles = rolesRes;
        _users = usersRes;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null || amount == 0) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  // ─── XODIMNI TAHRIRLASH DIALOGI ─────────────────────────────────
  void _showEditUserDialog(Map<String, dynamic> user) {
    // Joriy qiymatlarni olamiz
    int? selectedRoleId = user['position_id'];
    
    // Agar shaxsiy oylik/bonus yozilmagan bo'lsa, bo'sh turadi (Lavozimniki ishlaydi)
    final customSalaryCtrl = TextEditingController(
      text: user['custom_salary'] != null ? user['custom_salary'].toString() : ''
    );
    final customBonusCtrl = TextEditingController(
      text: user['custom_bonus_per_m2'] != null ? user['custom_bonus_per_m2'].toString() : ''
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Tanlangan rolni topamiz (ekranda uning standart oyligini ko'rsatib turish uchun)
            final selectedRole = _roles.firstWhere(
              (r) => r['id'] == selectedRoleId, 
              orElse: () => null
            );
            
            final isAup = selectedRole != null && selectedRole['role_type'] == 'aup';

            return AlertDialog(
              backgroundColor: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Xodimni tahrirlash"),
                  Text(user['full_name'] ?? 'Ismsiz xodim', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. LAVOZIMNI TANLASH
                      DropdownButtonFormField<int>(
                        value: selectedRoleId,
                        decoration: const InputDecoration(labelText: 'Lavozimni belgilang', border: OutlineInputBorder()),
                        items: _roles.map<DropdownMenuItem<int>>((role) {
                          return DropdownMenuItem<int>(
                            value: role['id'],
                            child: Text("${role['name']} (${role['role_type'] == 'aup' ? 'AUP' : 'Worker'})"),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedRoleId = val;
                            // Rol o'zgarganda shaxsiy oyliklarni tozalab tashlaymiz
                            customSalaryCtrl.clear();
                            customBonusCtrl.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 20),

                      // 2. SHAXSIY OYLIK VA BONUS (Override)
                      if (selectedRoleId != null) ...[
                        Text("Moliya va Maosh sozlamalari", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        // Kichik eslatma: Standart lavozim oyligi qancha o'zi?
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            "Lavozim bo'yicha standart:\nFiks: ${_formatMoney(selectedRole?['base_salary'])}\nBonus: ${_formatMoney(selectedRole?['bonus_per_m2'])}/m²",
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                        const SizedBox(height: 15),

                        if (isAup) ...[
                          const Text("Agar xodimga standartdan farqli oylik bermoqchi bo'lsangiz, quyida ko'rsating (aks holda bo'sh qoldiring):", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: customSalaryCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Shaxsiy fiks oylik', suffixText: "so'm", border: OutlineInputBorder()),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: customBonusCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Shaxsiy 1 m² ustamasi', suffixText: "so'm", border: OutlineInputBorder()),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: const Text("Bu xodim 'Worker' toifasida. Uning ish haqi faqat bajargan ishiga (Tariflarga) qarab hisoblanadi.", style: TextStyle(fontSize: 12, color: Colors.orange)),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E5BFF), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (selectedRoleId == null) return;
                    
                    try {
                      // Eski tizim buzilmasligi uchun asosiy rolni ham avtomat o'zgartiramiz
                      String legacyRole = isAup ? 'admin' : 'worker';

                      final updateData = {
                        'position_id': selectedRoleId,
                        'role': legacyRole,
                        'custom_salary': customSalaryCtrl.text.isEmpty ? null : double.tryParse(customSalaryCtrl.text),
                        'custom_bonus_per_m2': customBonusCtrl.text.isEmpty ? null : double.tryParse(customBonusCtrl.text),
                      };

                      await _supabase.from('profiles').update(updateData).eq('id', user['id']);
                      
                      if (mounted) {
                        Navigator.pop(context);
                        _fetchData(); // Ro'yxatni yangilash
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: const Text("Saqlash"),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Xodimlar Ro'yxati"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                
                // Super adminni ro'yxatda himoyalash
                final isSuperAdmin = user['is_super_admin'] == true;
                
                // Lavozimi yo'q bo'lsa
                final positionName = user['app_roles'] != null ? user['app_roles']['name'] : 'Lavozim belgilanmagan';
                final isAup = user['app_roles'] != null && user['app_roles']['role_type'] == 'aup';

                // Shaxsiy yoki Standart oylikni hisoblash
                double displaySalary = 0;
                double displayBonus = 0;
                
                if (isAup) {
                  displaySalary = user['custom_salary'] != null 
                      ? (user['custom_salary'] as num).toDouble() 
                      : (user['app_roles']['base_salary'] as num).toDouble();
                      
                  displayBonus = user['custom_bonus_per_m2'] != null 
                      ? (user['custom_bonus_per_m2'] as num).toDouble() 
                      : (user['app_roles']['bonus_per_m2'] as num).toDouble();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: isSuperAdmin ? const BorderSide(color: Colors.amber, width: 2) : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    leading: CircleAvatar(
                      backgroundColor: isSuperAdmin ? Colors.amber.withOpacity(0.2) : const Color(0xFF2E5BFF).withOpacity(0.15),
                      child: Icon(
                        isSuperAdmin ? Icons.star_rounded : Icons.person_rounded,
                        color: isSuperAdmin ? Colors.amber : const Color(0xFF2E5BFF),
                      ),
                    ),
                    title: Text(
                      user['full_name'] ?? 'Ism kiritilmagan', 
                      style: const TextStyle(fontWeight: FontWeight.bold)
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAup ? Colors.purple.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            positionName,
                            style: TextStyle(fontSize: 12, color: isAup ? Colors.purple : Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (isAup && !isSuperAdmin) ...[
                          const SizedBox(height: 4),
                          Text(
                            "Oylik: ${_formatMoney(displaySalary)} | +${_formatMoney(displayBonus)}/m²", 
                            style: const TextStyle(fontSize: 11, color: Colors.green)
                          ),
                        ]
                      ],
                    ),
                    trailing: isSuperAdmin 
                        ? const Icon(Icons.shield_rounded, color: Colors.amber)
                        : const Icon(Icons.edit_note_rounded, color: Colors.grey),
                    onTap: isSuperAdmin 
                        ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Super Adminni tahrirlab bo'lmaydi!")))
                        : () => _showEditUserDialog(user),
                  ),
                );
              },
            ),
    );
  }
}
