import 'package:flutter/material.dart';

import 'src/home_page.dart';
import 'src/look.dart';

void main() => runApp(const LoanAprApp());

class LoanAprApp extends StatelessWidget {
  const LoanAprApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Loan APR Calculator',
      debugShowCheckedModeBanner: false,
      theme: Look.light.theme(Brightness.light),
      darkTheme: Look.dark.theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}
