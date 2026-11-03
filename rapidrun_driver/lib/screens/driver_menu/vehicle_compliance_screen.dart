// File: rapidrun_driver/lib/screens/driver_menu/vehicle_compliance_screen.dart

import 'package:flutter/material.dart';

class VehicleComplianceScreen extends StatelessWidget {
  const VehicleComplianceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF121212);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
        title: const Text(
          'Vehicle & Compliance',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF142419),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF4ADE80).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF4ADE80), size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Apex Fleet Status: Verified',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'All background checks, auto insurance, and safety equipment are fully approved.',
                        style: TextStyle(color: Color(0xFF86EFAC), fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _complianceTile(
            icon: Icons.directions_car_outlined,
            title: 'Registered Vehicle',
            subtitle: '2022 Honda Civic (Silver) • Plate #ABC-1234',
            status: 'Active',
            statusColor: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          _complianceTile(
            icon: Icons.security_outlined,
            title: 'Auto Insurance Policy',
            subtitle: 'State Farm Commercial & Personal Auto',
            status: 'Valid to Oct 2026',
            statusColor: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          _complianceTile(
            icon: Icons.ac_unit_outlined,
            title: 'Insulated Thermal Bags',
            subtitle: 'Verified cold/frozen food transport certified',
            status: 'Verified',
            statusColor: Colors.greenAccent,
          ),
          const SizedBox(height: 12),
          _complianceTile(
            icon: Icons.badge_outlined,
            title: 'Driver License & Background Check',
            subtitle: 'Annual criminal & DMV records clearance',
            status: 'Passed',
            statusColor: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  static Widget _complianceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String status,
    required Color statusColor,
  }) {
    const gold = Color(0xFFE6B450);
    const cardSurface = Color(0xFF1C1C1C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: gold, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
