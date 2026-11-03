import 'package:flutter/material.dart';
import 'package:rapidrun/models/recommendation_type.dart';

// Recommendations screen implementation
class RecommendationsScreen extends StatelessWidget {
  final String title;
  final RecommendationType type;
  final String? sourceProduct;
  final String? categoryName;

  const RecommendationsScreen({
    Key? key,
    required this.title,
    required this.type,
    this.sourceProduct,
    this.categoryName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Recommendations Screen - Type: ${type.name}, Source: $sourceProduct, Category: $categoryName',
        ),
      ),
    );
  }
}
