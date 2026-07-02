import 'package:flutter/material.dart';

void main() {
  runApp(const FormaApp());
}

class FormaApp extends StatelessWidget {
  const FormaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Forma'),
        ),
      ),
    );
  }
}
