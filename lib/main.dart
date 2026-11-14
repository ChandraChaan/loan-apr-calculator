import 'package:flutter/material.dart';

import 'src/home_page.dart';

void main() => runApp(const LoanAprApp());

class LoanAprApp extends StatelessWidget {
  const LoanAprApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loan APR Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B7A4B),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B7A4B),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
