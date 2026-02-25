import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // O'zimizning profilni va unga ulangan lavozimni tortib kelamiz
      final response = await _supabase
          .from('profiles')
          .select('*, app_roles(name, role_type, base_salary, bonus_per_m2)')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _profileData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
      setState(() => _isLoading = false);
    }
  }

  String _formatMoney(dynamic amount) {
    if (amount == null || amount == 0) return "0 so'm";
    return "${NumberFormat("#,###").format(amount).replaceAll(',', ' ')} so'm";
  }

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    // Tizimdan chiqqandan so'ng avtomat Login ekraniga otib yuboradi (main.dart dagi stream orqali)
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profileData == null) {
      return const Scaffold(body: Center(child: Text("Ma'lumot topilmadi!")));
    }

    final String fullName = _profileData!['full_name'] ?? 'Ismsiz foydalanuvchi';
    final String phone = _profileData!['phone'] ?? '+998 -- --- -- --';
    final bool isSuperAdmin = _profileData!['is_super_admin'] == true;
    
    // Lavozim va Maosh ma'lumotlari
    final roleData = _profileData!['app_roles'];
    final String positionName = isSuperAdmin ? 'Korxona Rahbari' : (roleData != null ? roleData['name'] : 'Lavozim belgilanmagan');
    final bool isAup = roleData != null && roleData['role_type'] == 'aup';
    
    // Oylikni hisoblash (Shaxsiy ustun tursa o'shani, yo'qsa standartni oladi)
    double myBaseSalary = 0;
    double myBonusPerM2 = 0;
    
    if (isAup) {
      myBaseSalary = _profileData!['custom_salary'] != null 
          ? (_profileData!['custom_salary'] as num).toDouble() 
          : (roleData['base_salary'] as num).toDouble();
          
      myBonusPerM2 = _profileData!['custom_bonus_per_m2'] != null 
          ? (_profileData!['custom_bonus_per_m2'] as num).toDouble() 
          : (roleData['bonus_per_m2'] as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mening Profilim"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMyProfile,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. ASOSIY SHAXSIY MA'LUMOTLAR (Avatar va Ism)
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: isSuperAdmin ? Colors.amber.withOpacity(0.2) : const Color(0xFF2E5BFF).withOpacity(0.15),
                    child: Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        fontSize: 40, 
                        fontWeight: FontWeight.bold, 
                        color: isSuperAdmin ? Colors.amber.shade700 : const Color(0xFF2E5BFF)
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(phone, style: const TextStyle(fontSize: 16, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  
                  // Lavozim Belgisi (Badge)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSuperAdmin 
                          ? Colors.amber.withOpacity(0.2) 
                          : (isAup ? Colors.purple.withOpacity(0.1) : Colors.orange.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSuperAdmin 
                          ? Colors.amber 
                          : (isAup ? Colors.purple.withOpacity(0.5) : Colors.orange.withOpacity(0.5))
                      )
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSuperAdmin ? Icons.star_rounded : (isAup ? Icons.admin_panel_settings : Icons.engineering),
                          size: 18,
                          color: isSuperAdmin ? Colors.amber.shade700 : (isAup ? Colors.purple : Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          positionName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: isSuperAdmin ? Colors.amber.shade700 : (isAup ? Colors.purple : Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 35),

            // 2. MENING SHARTLARIM VA MAOSHIM
            const Text("Mening Shartlarim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: isSuperAdmin 
                  ? const Row(
                      children: [
                        Icon(Icons.diamond_rounded, color: Colors.amber, size: 30),
                        SizedBox(width: 15),
                        Expanded(child: Text("Siz tizim asoschisiz. Barcha moliyaviy oqimlar sizning nazoratingizda.", style: TextStyle(fontSize: 14))),
                      ],
                    )
                  : (isAup
                    ? Column(
                        children: [
                          _buildSalaryRow("Fiks oylik maosh:", _formatMoney(myBaseSalary)),
                          const Divider(height: 25),
                          _buildSalaryRow("Zakazdan ulush (1m² uchun):", _formatMoney(myBonusPerM2)),
                          const SizedBox(height: 10),
                          const Text("Oy yakunida umumiy yopilgan zakazlar kvadratiga qarab ustama qo'shib hisoblanadi.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      )
                    : const Row(
                        children: [
                          Icon(Icons.calculate_rounded, color: Colors.orange, size: 30),
                          SizedBox(width: 15),
                          Expanded(child: Text("Sizning maoshingiz Ishbay (Tariflar) tizimi asosida, bajargan ishlaringiz soni va hajmiga qarab hisoblanadi.", style: TextStyle(fontSize: 14))),
                        ],
                      )
                  ),
              ),
            ),

            const SizedBox(height: 35),

            // 3. SOZLAMALAR VA XAVFSIZLIK
            const Text("Sozlamalar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Column(
                children: [
                  // Agar kelajakda parolni o'zgartirish ulasangiz shu yerda bo'ladi
                  // ListTile(
                  //   leading: const Icon(Icons.lock_outline_rounded, color: Colors.grey),
                  //   title: const Text("Parolni o'zgartirish"),
                  //   trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  //   onTap: () {},
                  // ),
                  // const Divider(height: 1, indent: 50),
                  
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    title: const Text("Tizimdan chiqish", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    onTap: () => _showLogoutDialog(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
      ],
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Tizimdan chiqish"),
        content: const Text("Haqiqatan ham hisobingizdan chiqmoqchimisiz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: const Text("Chiqish"),
          ),
        ],
      ),
    );
  }
}
