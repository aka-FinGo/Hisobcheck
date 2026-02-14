import 'package:flutter/material.dart';

void main() {
  runApp(const HisobCheckApp());
}

class HisobCheckApp extends StatelessWidget {
  const HisobCheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HisobCheck',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// Tranzaksiya modeli (Ma'lumot turi)
class Transaction {
  final String id;
  final String title;
  final double amount;
  final bool isExpense; // True = Chiqim, False = Kirim
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isExpense,
    required this.date,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Tranzaksiyalar ro'yxati (Baza o'rnida turadi)
  final List<Transaction> _transactions = [];

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  
  // Hozirgi balansni hisoblash
  double get _totalBalance {
    double balance = 0;
    for (var tx in _transactions) {
      if (tx.isExpense) {
        balance -= tx.amount;
      } else {
        balance += tx.amount;
      }
    }
    return balance;
  }

  // Yangi tranzaksiya qo'shish oynasi
  void _startAddNewTransaction(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Nima uchun? (Izoh)'),
                controller: _titleController,
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Summa'),
                controller: _amountController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _submitData(true), // Chiqim
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
                    icon: const Icon(Icons.arrow_downward, color: Colors.red),
                    label: const Text("Chiqim", style: TextStyle(color: Colors.red)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _submitData(false), // Kirim
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100),
                    icon: const Icon(Icons.arrow_upward, color: Colors.green),
                    label: const Text("Kirim", style: TextStyle(color: Colors.green)),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _submitData(bool isExpense) {
    final enteredTitle = _titleController.text;
    final enteredAmount = double.tryParse(_amountController.text);

    if (enteredTitle.isEmpty || enteredAmount == null || enteredAmount <= 0) {
      return; // Agar ma'lumot xato bo'lsa, hech narsa qilma
    }

    setState(() {
      _transactions.add(
        Transaction(
          id: DateTime.now().toString(),
          title: enteredTitle,
          amount: enteredAmount,
          isExpense: isExpense,
          date: DateTime.now(),
        ),
      );
    });

    // Inputlarni tozalash va oynani yopish
    _titleController.clear();
    _amountController.clear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("HisobCheck"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 1. Balans Kartasi
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade800,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
            ),
            child: Column(
              children: [
                const Text("Umumiy Balans", style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 10),
                Text(
                  "${_totalBalance.toStringAsFixed(0)} so'm",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // 2. Ro'yxat
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text("Hozircha hisob-kitob yo'q!"))
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = _transactions[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: tx.isExpense ? Colors.red : Colors.green,
                            child: Icon(
                              tx.isExpense ? Icons.remove : Icons.add,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(tx.date.toString().substring(0, 16)),
                          trailing: Text(
                            "${tx.isExpense ? '-' : '+'}${tx.amount} so'm",
                            style: TextStyle(
                              color: tx.isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _startAddNewTransaction(context),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
