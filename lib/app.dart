import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/expenses/presentation/screens/expense_home_screen.dart';

class ExpenseProApp extends StatelessWidget {
  const ExpenseProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Pro',
      debugShowCheckedModeBanner: false,
      theme: ExpenseProTheme.light,
      home: const ExpenseHomeScreen(),
    );
  }
}
