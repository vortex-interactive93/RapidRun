import 'package:flutter/material.dart';

// Favorites screen implementation
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: Center(child: const Text('Favorites Screen')),
    );
  }
}
