import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _userRole = 'worker'; // Standart qiymat
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    // Profillar jadvalidan userni topamiz
    final data = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    setState(() {
      _userRole = data['role'] ?? 'worker';
      _userName = data['full_name'] ?? 'Foydalanuvchi';
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Roliga qarab boshqa ekran ko'rsatamiz
    return Scaffold(
      appBar: AppBar(
        title: Text(_userRole == 'admin' ? "Admin Panel" : "Ishchi Kabineti"),
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(_userName),
              accountEmail: Text(_userRole.toUpperCase()),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(_userName.isNotEmpty ? _userName[0] : "A"),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Asosiy"),
              onTap: () {},
            ),
             // Faqat Adminlar ko'radigan menu
            if (_userRole == 'admin')
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text("Xodimlar"),
                onTap: () {},
              ),
            // Hammani ko'radigan menu
            ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text("Mening Hamyonim"),
              onTap: () {},
            ),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _userRole == 'admin' ? Icons.admin_panel_settings : Icons.engineering,
              size: 100,
              color: Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              "Xush kelibsiz, $_userName!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "Sizning vazifangiz: $_userRole",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
