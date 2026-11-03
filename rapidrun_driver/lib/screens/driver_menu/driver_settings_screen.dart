// File: rapidrun_driver/lib/screens/driver_menu/driver_settings_screen.dart

import 'package:flutter/material.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool _audioChime = true;
  bool _hapticVibration = true;
  bool _batterySaver = false;
  bool _autoAcceptHighPay = false;

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE6B450);
    const bg = Color(0xFF121212);
    const cardSurface = Color(0xFF1C1C1C);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        iconTheme: const IconThemeData(color: gold),
        title: const Text(
          'App Settings & Audio Alerts',
          style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'DISPATCH ALERTS & FEEDBACK',
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('High-Priority Offer Chime', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Play distinctive chime on incoming offers', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _audioChime,
                  activeColor: gold,
                  onChanged: (v) => setState(() => _audioChime = v),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text('Haptic Vibration Feedback', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Vibrate phone on offer arrival and countdowns', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _hapticVibration,
                  activeColor: gold,
                  onChanged: (v) => setState(() => _hapticVibration = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              'PERFORMANCE & BATTERY',
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Battery Saver GPS Polling', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Reduce location polling frequency when idle', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _batterySaver,
                  activeColor: gold,
                  onChanged: (v) => setState(() => _batterySaver = v),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text('Auto-Accept High-Payout Batches (> \$25)', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Instantly claim high-value offers matching your radius', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  value: _autoAcceptHighPay,
                  activeColor: gold,
                  onChanged: (v) => setState(() => _autoAcceptHighPay = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
