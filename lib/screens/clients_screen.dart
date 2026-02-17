import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'orders_list_screen.dart'; // <--- YANGI SAHIFANI ULAYMIZ

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  // Ma'lumotlar
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  List<Map<String, dynamic>> _orders = [];
  
  // Statistika
  int _totalClients = 0;
  int _newClients = 0;
  int _activeClients = 0; // Faol mijozlar (zakazi borlar)

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        final name = (client['full_name'] ?? client['name'] ?? "").toString().toLowerCase();
        final phone = (client['phone'] ?? "").toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _supabase.from('clients').select().order('created_at', ascending: false),
        _supabase.from('orders').select('client_id'), // Faol mijozlarni aniqlash uchun
      ]);

      final clientsData = List<Map<String, dynamic>>.from(results[0]);
      final ordersData = List<Map<String, dynamic>>.from(results[1]);

      // Statistikani hisoblash
      final now = DateTime.now();
      int newCount = 0;
      
      // Faol mijozlar: Zakazlar ro'yxatida ID si bor mijozlar
      final activeClientIds = ordersData.map((o) => o['client_id']).toSet();
      int activeCount = clientsData.where((c) => activeClientIds.contains(c['id'])).length;

      for (var c in clientsData) {
        if (c['created_at'] != null) {
          final created = DateTime.parse(c['created_at']);
          if (created.month == now.month && created.year == now.year) {
            newCount++;
          }
        }
      }

      if (mounted) {
        setState(() {
          _allClients = clientsData;
          _filteredClients = clientsData;
          _orders = ordersData;
          
          _totalClients = clientsData.length;
          _newClients = newCount;
          _activeClients = activeCount;
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Xato: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- YANGI MIJOZ QO'SHISH DIALOGI ---
  void _showAddClientDialog() {
    
