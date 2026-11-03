// File: lib/screens/settings/address_book_screen.dart

import 'package:flutter/material.dart';
import '../../services/address_book_service.dart';
import '../../services/google_places_service.dart';
import '../../models/address.dart';

/// Saved delivery address manager connected to AddressBookService (shared with Checkout).
class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});
  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  final _service = AddressBookService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChange);
    _service.bootstrap();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) setState(() {});
  }

  void _addAddress() async {
    final addr = await showDialog<Address>(
      context: context,
      builder: (_) => const _EditAddressDialog(),
    );
    if (addr != null) {
      await _service.upsert(addr);
    }
  }

  void _edit(Address existing) async {
    final addr = await showDialog<Address>(
      context: context,
      builder: (_) => _EditAddressDialog(existing: existing),
    );
    if (addr != null) {
      await _service.upsert(addr);
    }
  }

  void _remove(Address a) async {
    await _service.remove(a.id);
  }

  void _setDefault(Address a) async {
    await _service.upsert(a.copyWith(isDefault: true));
  }

  @override
  Widget build(BuildContext context) {
    final addresses = _service.all;
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: const Text('Address Book'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFC107),
        foregroundColor: Colors.black,
        onPressed: _addAddress,
        child: const Icon(Icons.add_location_alt_outlined),
      ),
      body: addresses.isEmpty
          ? const Center(
              child: Text(
                'No addresses saved yet. Tap + to add one.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: addresses.length,
              itemBuilder: (_, i) {
                final a = addresses[i];
                final isDefault = a.isDefault;
                final labelText = a.line1.isNotEmpty ? a.line1 : 'Address';
                final line2Text = a.line2 != null && a.line2!.isNotEmpty ? ' ${a.line2}' : '';
                final nameText = a.fullName.isNotEmpty ? '${a.fullName}\n' : '';
                return Card(
                  color: const Color(0xFF262626),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isDefault ? const Color(0xFFFFC107) : Colors.white10,
                      width: isDefault ? 1.4 : 0.8,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Text(
                          labelText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                color: Color(0xFFFFC107),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$nameText${a.line1}$line2Text\n${a.city}, ${a.state} ${a.postalCode}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ),
                    isThreeLine: true,
                    leading: Icon(
                      isDefault ? Icons.star : Icons.location_on_outlined,
                      color: isDefault ? const Color(0xFFFFC107) : Colors.white38,
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white70),
                      color: const Color(0xFF2A2A2A),
                      onSelected: (v) {
                        switch (v) {
                          case 'edit':
                            _edit(a);
                            break;
                          case 'delete':
                            _remove(a);
                            break;
                          case 'default':
                            _setDefault(a);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit', style: TextStyle(color: Colors.white)),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                        if (!isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Set Default', style: TextStyle(color: Color(0xFFFFC107))),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EditAddressDialog extends StatefulWidget {
  final Address? existing;
  const _EditAddressDialog({this.existing});
  @override
  State<_EditAddressDialog> createState() => _EditAddressDialogState();
}

class _EditAddressDialogState extends State<_EditAddressDialog> {
  final _fullName = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();

  List<PlacePrediction> _predictions = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _fullName.text = e.fullName;
      _line1.text = e.line1;
      _line2.text = e.line2 ?? '';
      _city.text = e.city;
      _state.text = e.state;
      _zip.text = e.postalCode;
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    super.dispose();
  }

  void _onLine1Changed(String val) async {
    if (val.trim().length < 3) {
      setState(() => _predictions = []);
      return;
    }
    setState(() => _searching = true);
    final results = await GooglePlacesService.instance.getAutocomplete(val);
    if (mounted) {
      setState(() {
        _predictions = results;
        _searching = false;
      });
    }
  }

  void _selectPrediction(PlacePrediction prediction) async {
    setState(() {
      _line1.text = prediction.description;
      _predictions = [];
    });
    final details = await GooglePlacesService.instance.getPlaceDetails(prediction.placeId);
    if (details != null && mounted) {
      setState(() {
        _line1.text = details.line1.isNotEmpty ? details.line1 : prediction.description;
        if (details.city.isNotEmpty) _city.text = details.city;
        if (details.state.isNotEmpty) _state.text = details.state;
        if (details.postalCode.isNotEmpty) _zip.text = details.postalCode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF262626),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.existing == null ? 'Add Address' : 'Edit Address',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(_fullName, 'Full Name'),
            _autocompleteLine1Field(),
            _field(_line2, 'Apt, Suite, Unit (optional)'),
            _field(_city, 'City'),
            _field(_state, 'State'),
            _field(_zip, 'ZIP Code'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (_line1.text.trim().isEmpty) return;
            final now = DateTime.now().millisecondsSinceEpoch.toString();
            final id = widget.existing?.id ?? 'addr_$now';
            Navigator.pop(
              context,
              Address(
                id: id,
                fullName: _fullName.text.trim(),
                line1: _line1.text.trim(),
                line2: _line2.text.trim().isNotEmpty ? _line2.text.trim() : null,
                city: _city.text.trim(),
                state: _state.text.trim(),
                postalCode: _zip.text.trim(),
                isDefault: widget.existing?.isDefault ?? false,
              ),
            );
          },
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _autocompleteLine1Field() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _line1,
            onChanged: _onLine1Changed,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Address Line 1 (Auto-fills)',
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF1F1F1F),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFC107)),
                      ),
                    )
                  : const Icon(Icons.location_searching, color: Colors.white38, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.white12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFFFC107)),
              ),
            ),
          ),
          if (_predictions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _predictions.length,
                itemBuilder: (_, index) {
                  final p = _predictions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on, color: Color(0xFFFFC107), size: 18),
                    title: Text(
                      p.description,
                      style: const TextStyle(color: Colors.white, fontSize: 12.5),
                    ),
                    onTap: () => _selectPrediction(p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFF1F1F1F),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFFC107)),
          ),
        ),
      ),
    );
  }
}
