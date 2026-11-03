import 'package:flutter/material.dart';
import 'package:rapidrun/models/recommendation_type.dart';

class RecommendationCarousel extends StatelessWidget {
  final String title;
  final String? userId;
  final RecommendationType? type;
  final bool? showViewAll;

  const RecommendationCarousel({
    Key? key,
    required this.title,
    this.userId,
    this.type,
    this.showViewAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: Center(
        child: Text(
          'Recommendation Carousel - $title, User: $userId, Type: ${type?.name}, Show View All: $showViewAll',
        ),
      ),
    );
  }
}
