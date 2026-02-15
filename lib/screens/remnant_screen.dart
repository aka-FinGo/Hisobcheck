import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RemnantScreen extends StatefulWidget {
  const RemnantScreen({super.key});

  @override
  State<RemnantScreen> createState() => _RemnantScreenState();
}

class _RemnantScreenState extends State<RemnantScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _remnants = [];
  List<dynamic> _filteredRemnants = []; // Qidiruv uchun
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRemnants();
  }

  // Bazadan qoldiqlarni yuklash
  Future<void> _loadRemnants() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('remnants')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _remnants = data;
        _filteredRemnants = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMsg("Xatolik: $e");
    }
  }

  // Qidiruv mantiqi (Rangiga qarab)
  void _filterRemnants(String query) {
    setState(() {
      _filteredRemnants = _remnants
          .where((r) => r['color_name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- 2-QISM DAVOM ETADI (Pastdagi xabarda) ---
