import 'package:flutter/material.dart';

import 'package:demo_odbc/screens/cliente_query_screen.dart';

void main() => runApp(const DemoOdbcApp());

class DemoOdbcApp extends StatelessWidget {
  const DemoOdbcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo ODBC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ClienteQueryScreen(),
    );
  }
}
