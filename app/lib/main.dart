import 'package:flutter/material.dart';
import '../front/about_page.dart';
import '../front/content_page.dart';
import '../front/home_page.dart';
import '../entities/user.dart';
import '../controller/list_user.dart';

class Income {
  final int id;
  String description;
  double amount;
  DateTime date;

  Income({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Income.fromJson(Map<String, dynamic> json) => Income(
        id: json['id'],
        description: json['description'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
      );
}

class Expense {
  final int id;
  String description;
  double amount;
  DateTime date;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        description: json['description'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
      );
}

class IncomeCategory {
  final int id;
  String name;

  IncomeCategory({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory IncomeCategory.fromJson(Map<String, dynamic> json) => IncomeCategory(
        id: json['id'],
        name: json['name'],
      );
}

class ExpenseCategory {
  final int id;
  String name;

  ExpenseCategory({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) => ExpenseCategory(
        id: json['id'],
        name: json['name'],
      );
}

class GenericPrinter<T> {
  final T obj;
  GenericPrinter(this.obj);

  void printFormatted() {
    if (obj is List) {
      _formatAndPrintList(obj as List);
    } else {
      print(obj.toString());
    }
  }

  void _formatAndPrintList(List list) {
    final buffer = StringBuffer('[');

    if (list.isEmpty) {
      buffer.write(']');
      print(buffer.toString());
      return;
    }

    buffer.write('\n');
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      final isLast = i == list.length - 1;
      final comma = isLast ? '' : ',';

      if (item is Map) {
        buffer.write('  ${_formatMapItem(item)}$comma\n');
      } else {
        buffer.write('  ${item.toString()}$comma\n');
      }
    }
    buffer.write(']');
    print(buffer.toString());
  }

  String _formatMapItem(Map item) {
    if (item.isEmpty) return '{}';
    final entries = item.entries.map((e) {
      return "'${e.key}': '${e.value}'";
    }).join(', ');
    return '{$entries}';
  }
}

// Dữ liệu mẫu
List<User> users = [
  User(id: 1, name: 'Quan', email: 'quan@gmail.com', password: '12345'),
  User(id: 2, name: 'Hieu', email: 'hieu@gmail.com', password: '12345'),
  User(id: 3, name: 'Cuong', email: 'cuong@gmail.com', password: '12345'),
];

List<IncomeCategory> incomeCategories = [
  IncomeCategory(id: 1, name: 'Lương'),
  IncomeCategory(id: 2, name: 'Làm thêm'),
];

List<ExpenseCategory> expenseCategories = [
  ExpenseCategory(id: 1, name: 'Ăn uống'),
  ExpenseCategory(id: 2, name: 'Xăng xe'),
  ExpenseCategory(id: 3, name: 'Du lịch'),
];

List<Income> incomes = [
  Income(id: 1, description: 'Sinh hoạt phí', amount: 1000000, date: DateTime.now()),
];

List<Expense> expenses = [
  Expense(id: 1, description: 'Ăn uống', amount: 30000, date: DateTime.now()),
  Expense(id: 2, description: 'Xăng xe', amount: 100000, date: DateTime.now()),
];

void main() {

  var students = [
    {'studentID': '23010580', 'fullname': 'Lê Anh Quân'},
    {'studentID': '23010827', 'fullname': 'Nguyễn Đình Hiếu'},
    {'studentID': '23010224', 'fullname': 'Lê Mạnh Cường'},
  ];

  final printer = GenericPrinter<List<Map<String, String>>>(students);
  printer.printFormatted();
  
  final initialUsers = [
    User(id: 1, name: 'Quan', email: 'quan@gmail.com', password: '12345'),
    User(id: 2, name: 'Hieu', email: 'hieu@gmail.com', password: '12345'),
  ];

  final listRepo = UserList(initialUsers);

  // Create
  final created = listRepo.create(User(id: 3, name: 'Cuong', email: 'cuong@gmail.com', password: '12345'));
  print('Created: $created'); // true

  // Read all
  final all = listRepo.readAll();
  print('All users: ${all.length}');

  // Read by id
  final u2 = listRepo.readById(2);
  print('User 2: ${u2?.name}');

  // Update
  final updated = listRepo.updateById(2, name: 'Hieu Updated', email: 'hieu_new@gmail.com');
  print('Updated: $updated');

  // Delete (tùy chọn)
  final deleted = listRepo.deleteById(1);
  print('Deleted id 1: $deleted');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'App của Quan, Hieu và Cuong'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int counter = 0;
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    ContentPage(),
    AboutPage(),
  ];

  double get totalIncome => incomes.fold(0.0, (sum, income) => sum + income.amount);
  double get totalExpense => expenses.fold(0.0, (sum, expense) => sum + expense.amount);

  void incrementCounter() {
    setState(() {
      counter++;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/home',
      routes: {
        '/home': (context) => const HomePage(),
        '/content': (context) => const ContentPage(),
        '/contact': (context) => const AboutPage(),
      },
      home: Scaffold(
        body: _pages[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
            if (index == 0) {
              Navigator.pushReplacementNamed(context, '/home');
            } else if (index == 1) {
              Navigator.pushReplacementNamed(context, '/content');
            } else if (index == 2) {
              Navigator.pushReplacementNamed(context, '/contact');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.info), label: 'Content'),
            BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'About'),
          ],
        ),
      ),
    );
  }
}
