import 'package:flutter/material.dart';

// Recently viewed carousel widget implementation
class RecentlyViewedCarousel extends StatelessWidget {
  const RecentlyViewedCarousel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Center(child: Text('Recently Viewed Carousel')),
    );
  }
}
