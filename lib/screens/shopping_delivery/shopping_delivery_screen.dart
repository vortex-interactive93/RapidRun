// File: lib/screens/shopping_delivery/shopping_delivery_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'aldi_store_screen.dart';
import '../catalog/bbw_store_screen.dart';
import '../../widgets/home/flagship_store_card.dart';
import '../../services/config_service.dart';

class ShoppingDeliveryScreen extends StatefulWidget {
  const ShoppingDeliveryScreen({super.key});

  @override
  State<ShoppingDeliveryScreen> createState() => _ShoppingDeliveryScreenState();
}

class _ShoppingDeliveryScreenState extends State<ShoppingDeliveryScreen> {
  @override
  void initState() {
    super.initState();
    ConfigService.instance.ensureListening();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE5A93C);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        title: const Text(
          'Flagship Destinations',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF14171E),
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 1. Bath & Body Works Flagship Card
          FlagshipStoreCard(
            type: FlagshipType.bathAndBodyWorks,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BbwStoreScreen(),
                ),
              );
            },
          ),

          // 2. ALDI Market Flagship Card
          FlagshipStoreCard(
            type: FlagshipType.aldi,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AldiStoreScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
