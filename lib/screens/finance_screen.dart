import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_themes.dart';
import '../widgets/glass_card.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  
  bool _isLoading = true;
  bool _isAdmin = false;
  String _currentUserId = '';
  
  List<Map<String, dynamic>> _myTransactions = [];
  List<Map<String, dynamic>> _employeeList = [];
  
  // For Admin view
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;
  List<Map<String, dynamic>> _selectedEmployeeTransactions = [];
  bool _isLoadingEmployeeDetails = false;

  final _fmt = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser!.id;
    _tabController = TabController(length: 2, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check if Admin/AUP
      final profile = await _supabase.from('profiles').select('is_super_admin, app_roles(role_type)').eq('id', _currentUserId).single();
      _isAdmin = (profile['is_super_admin'] == true) || (profile['app_roles']?['role_type'] == 'aup');
      
      if (!_isAdmin) {
        _tabController = TabController(length: 1, vsync: this);
      } else {
        // Load all employees for admin
        final employees = await _supabase.from('profiles').select('id, full_name').order('full_name');
        _employeeList = List<Map<String, dynamic>>.from(employees);
      }

      // 2. Load my transactions
      await _loadMyTransactions();
      
    } catch (e) {
      debugPrint("Finance Init Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyTransactions() async {
    final res = await _supabase.from('personal_transactions').select().eq('user_id', _currentUserId).order('created_at', ascending: false);
    _myTransactions = List<Map<String, dynamic>>.from(res);
  }

  Future<void> _loadEmployeeTransactions(String userId) async {
    setState(() => _isLoadingEmployeeDetails = true);
    try {
      final res = await _supabase.from('personal_transactions').select().eq('user_id', userId).order('created_at', ascending: false);
      setState(() {
        _selectedEmployeeTransactions = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint("Load Employee Trans Error: $e");
    } finally {
      setState(() => _isLoadingEmployeeDetails = false);
    }
  }

  void _addTransaction() {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedCategory = 'Ish haqi';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 25, right: 25, top: 25,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Maosh/Daromad qo'shish", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E5B55))),
              const SizedBox(height: 20),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Summa",
                  prefixIcon: const Icon(Icons.money, color: Color(0xFF2E5B55)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: "Izoh",
                  prefixIcon: const Icon(Icons.notes, color: Color(0xFF2E5B55)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setModalState(() => selectedDate = d);
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(DateFormat('dd.MM.yyyy').format(selectedDate)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () async {
                    if (amountCtrl.text.isEmpty) return;
                    try {
                      await _supabase.from('personal_transactions').insert({
                        'user_id': _currentUserId,
                        'type': 'salary',
                        'amount': double.parse(amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')),
                        'category': selectedCategory,
                        'description': descCtrl.text.trim(),
                        'created_at': selectedDate.toIso8601String(),
                      });
                      Navigator.pop(ctx);
                      _loadMyTransactions();
                      setState(() {});
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Xato: $e")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E5B55),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text("Saqlash", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1FAF8),
      appBar: AppBar(
        title: const Text("Moliya", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF2E5B55),
        bottom: _isAdmin ? TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2E5B55),
          indicatorColor: const Color(0xFF2E5B55),
          tabs: const [
            Tab(text: "Mening tarixim"),
            Tab(text: "Xodimlar"),
          ],
        ) : null,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTransaction,
        backgroundColor: const Color(0xFF2E5B55),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isAdmin 
        ? TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionList(_myTransactions),
              _buildAdminView(),
            ],
          )
        : _buildTransactionList(_myTransactions),
    );
  }

  Widget _buildTransactionList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.teal.withOpacity(0.2)),
            const SizedBox(height: 15),
            const Text("Hozircha ma'lumot yo'q", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final date = DateTime.parse(item['created_at']);
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.south_west, color: Colors.teal, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['description']?.isEmpty == true ? "Daromad" : item['description'], 
                         style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd MMMM, HH:mm').format(date), 
                         style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              Text("+${_fmt.format(item['amount'])}", 
                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAdminView() {
    return Column(
      children: [
        // Employee Selector
        Container(
          height: 80,
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _employeeList.length,
            itemBuilder: (ctx, i) {
              final emp = _employeeList[i];
              final isSelected = _selectedEmployeeId == emp['id'];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmployeeId = emp['id'];
                    _selectedEmployeeName = emp['full_name'];
                  });
                  _loadEmployeeTransactions(emp['id']);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF2E5B55) : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: isSelected ? Colors.transparent : Colors.black12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    emp['full_name'] ?? "Noma'lum",
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        Expanded(
          child: _selectedEmployeeId == null 
            ? const Center(child: Text("Xodimni tanlang", style: TextStyle(color: Colors.grey)))
            : _isLoadingEmployeeDetails 
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.person, size: 20, color: Color(0xFF2E5B55)),
                          const SizedBox(width: 8),
                          Text(_selectedEmployeeName ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Text("${_selectedEmployeeTransactions.length} ta yozuv", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(child: _buildTransactionList(_selectedEmployeeTransactions)),
                  ],
                ),
        ),
      ],
    );
  }
}
