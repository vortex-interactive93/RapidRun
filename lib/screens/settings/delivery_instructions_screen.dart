import 'package:flutter/material.dart';
import '../../services/preferences_service.dart';

class DeliveryInstructionsScreen extends StatefulWidget {
  const DeliveryInstructionsScreen({super.key});
  @override
  State<DeliveryInstructionsScreen> createState() =>
      _DeliveryInstructionsScreenState();
}

class _DeliveryInstructionsScreenState
    extends State<DeliveryInstructionsScreen> {
  bool _leaveAtDoor = true;
  bool _ringBell = false;
  final _gateCode = TextEditingController();
  final _notes = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _leaveAtDoor = await PreferencesService.getLeaveAtDoor();
    _ringBell = await PreferencesService.getRingBell();
    _gateCode.text = await PreferencesService.getGateCode();
    _notes.text = await PreferencesService.getDeliveryNotes();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    await PreferencesService.setLeaveAtDoor(_leaveAtDoor);
    await PreferencesService.setRingBell(_ringBell);
    await PreferencesService.setGateCode(_gateCode.text.trim());
    await PreferencesService.setDeliveryNotes(_notes.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delivery instructions saved')),
    );
  }

  @override
  void dispose() {
    _gateCode.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery Instructions')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                SwitchListTile(
                  title: const Text('Leave at door'),
                  value: _leaveAtDoor,
                  onChanged: (v) => setState(() => _leaveAtDoor = v),
                  subtitle: const Text(
                    'Driver will leave at door when possible',
                  ),
                ),
                SwitchListTile(
                  title: const Text('Ring bell / knock'),
                  value: _ringBell,
                  onChanged: (v) => setState(() => _ringBell = v),
                ),
                TextField(
                  controller: _gateCode,
                  decoration: const InputDecoration(
                    labelText: 'Gate / Access Code',
                    hintText: 'e.g., #1234 or call 555-1234',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Delivery notes',
                    hintText: 'Landmarks, apartment details, etc.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('Save')),
              ],
            ),
    );
  }
}
