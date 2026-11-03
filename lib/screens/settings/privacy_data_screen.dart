import 'package:flutter/material.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});
  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool personalizedRecs = true;
  bool allowTracking = true;
  bool showCarbon = false;
  bool showWhy = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Data')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Personalized Recommendations'),
            subtitle: const Text(
              'Use your interactions to improve suggestions',
            ),
            value: personalizedRecs,
            onChanged: (v) => setState(() => personalizedRecs = v),
          ),
          SwitchListTile(
            title: const Text('Ad / Tracking Consent'),
            subtitle: Text(
              allowTracking ? 'Enabled' : 'Disabled (more privacy)',
            ),
            value: allowTracking,
            onChanged: (v) => setState(() => allowTracking = v),
          ),
          SwitchListTile(
            title: const Text('Carbon Footprint Insights'),
            value: showCarbon,
            onChanged: (v) => setState(() => showCarbon = v),
          ),
          SwitchListTile(
            title: const Text('Show "Why this recommendation"'),
            value: showWhy,
            onChanged: (v) => setState(() => showWhy = v),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Purchase CSV'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Request Data Deletion'),
            onTap: () {},
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'These controls are local stubs now. Next step: persist to Firestore & enforce in analytics and recommendation pipelines.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
