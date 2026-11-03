import 'package:flutter/material.dart';

class AccessibilityPreferencesScreen extends StatefulWidget {
  const AccessibilityPreferencesScreen({super.key});
  @override
  State<AccessibilityPreferencesScreen> createState() =>
      _AccessibilityPreferencesScreenState();
}

class _AccessibilityPreferencesScreenState
    extends State<AccessibilityPreferencesScreen> {
  double textScale = 1.0;
  bool highContrast = false;
  bool reduceMotion = false;
  bool voiceSearch = true;
  bool haptics = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            title: const Text('Text Size'),
            subtitle: Slider(
              value: textScale,
              min: 0.8,
              max: 1.6,
              divisions: 8,
              label: textScale.toStringAsFixed(1),
              onChanged: (v) => setState(() => textScale = v),
            ),
          ),
          SwitchListTile(
            title: const Text('High Contrast'),
            value: highContrast,
            onChanged: (v) => setState(() => highContrast = v),
          ),
          SwitchListTile(
            title: const Text('Reduce Motion'),
            value: reduceMotion,
            onChanged: (v) => setState(() => reduceMotion = v),
          ),
          SwitchListTile(
            title: const Text('Enable Voice Search'),
            value: voiceSearch,
            onChanged: (v) => setState(() => voiceSearch = v),
          ),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            value: haptics,
            onChanged: (v) => setState(() => haptics = v),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Changes previewed immediately where possible. Persist + apply at app level in a future iteration.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
