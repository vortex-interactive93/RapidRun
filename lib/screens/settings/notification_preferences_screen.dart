import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool orderStatus = true;
  bool priceDrops = true;
  bool lowInventory = false;
  bool promos = true;
  bool substitutions = true;
  bool digestMode = false; // false = real-time
  TimeOfDay quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    orderStatus = await PreferencesService.getOrderStatusChannel();
    priceDrops = await PreferencesService.getPriceDropsChannel();
    lowInventory = await PreferencesService.getLowInventoryChannel();
    promos = await PreferencesService.getPromosChannel();
    substitutions = await PreferencesService.getSubstitutionsChannel();
    digestMode = await PreferencesService.getDigestMode();
    final qs = await PreferencesService.getQuietStart();
    final qe = await PreferencesService.getQuietEnd();
    quietStart = TimeOfDay(hour: qs.hour, minute: qs.minute);
    quietEnd = TimeOfDay(hour: qe.hour, minute: qe.minute);
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(bool start) async {
    final initial = start ? quietStart : quietEnd;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (start)
          quietStart = picked;
        else
          quietEnd = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Order Status Updates'),
            value: orderStatus,
            onChanged: (v) async {
              setState(() => orderStatus = v);
              await PreferencesService.setOrderStatusChannel(v);
            },
          ),
          SwitchListTile(
            title: const Text('Price Drops'),
            value: priceDrops,
            onChanged: (v) async {
              setState(() => priceDrops = v);
              await PreferencesService.setPriceDropsChannel(v);
            },
          ),
          SwitchListTile(
            title: const Text('Low Inventory Alerts'),
            value: lowInventory,
            onChanged: (v) async {
              setState(() => lowInventory = v);
              await PreferencesService.setLowInventoryChannel(v);
            },
          ),
          SwitchListTile(
            title: const Text('Promotions'),
            value: promos,
            onChanged: (v) async {
              setState(() => promos = v);
              await PreferencesService.setPromosChannel(v);
            },
          ),
          SwitchListTile(
            title: const Text('Substitution Requests'),
            value: substitutions,
            onChanged: (v) async {
              setState(() => substitutions = v);
              await PreferencesService.setSubstitutionsChannel(v);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Digest Mode (Daily Summary)'),
            subtitle: Text(
              digestMode ? 'Daily summary at 8 AM' : 'Real-time alerts',
            ),
            value: digestMode,
            onChanged: (v) async {
              setState(() => digestMode = v);
              await PreferencesService.setDigestMode(v);
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Quiet Hours Start'),
            subtitle: Text('${quietStart.format(context)}'),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              await _pickTime(true);
              await PreferencesService.setQuietStart(
                quietStart.hour,
                quietStart.minute,
              );
            },
          ),
          ListTile(
            title: const Text('Quiet Hours End'),
            subtitle: Text('${quietEnd.format(context)}'),
            trailing: const Icon(Icons.schedule),
            onTap: () async {
              await _pickTime(false);
              await PreferencesService.setQuietEnd(
                quietEnd.hour,
                quietEnd.minute,
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'During quiet hours, non-urgent notifications are suppressed. Order status critical alerts may still appear.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
