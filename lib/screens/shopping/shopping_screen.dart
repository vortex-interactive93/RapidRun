import 'package:flutter/material.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping'),
        backgroundColor: const Color(0xFF181818),
      ),
      body: Center(child: const Text('Shopping Screen')),
    );
  }
}
