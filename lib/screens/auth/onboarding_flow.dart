import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Multi-step onboarding wizard replacing single complete profile screen.
/// Steps: Welcome -> Profile -> Preferences -> Finish.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  File? _imageFile;
  bool _notifications = true;
  bool _mergeOnLogin = true;
  bool _saving = false;
  String? _error;

  static const _prefsKeyNotifs = 'settings_notifications';
  static const _prefsKeyMerge = 'settings_mergeOnLogin';

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    if (u != null && (u.displayName ?? '').isNotEmpty) {
      _nameCtrl.text = u.displayName!;
    }
    _phoneCtrl.text = u?.phoneNumber ?? '';
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notifications = prefs.getBool(_prefsKeyNotifs) ?? _notifications;
        _mergeOnLogin = prefs.getBool(_prefsKeyMerge) ?? _mergeOnLogin;
      });
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: initial,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = 'Enter your full name');
      return;
    }
    if (_dob == null) {
      setState(() => _error = 'Select date of birth');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? photoUrl = user.photoURL;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'user_photos/${user.uid}.jpg',
        );
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }
      if ((user.displayName ?? '').isEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dob': Timestamp.fromDate(_dob!),
        'photoUrl': photoUrl,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      // Persist preferences selected during onboarding.
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefsKeyNotifs, _notifications);
        await prefs.setBool(_prefsKeyMerge, _mergeOnLogin);
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_step < 3) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Started'),
        leading: _step == 0
            ? null
            : IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back)),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Welcome to RapidRun',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Just a few quick steps to finish setting up your account.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              ElevatedButton(onPressed: _next, child: const Text('Let\'s Go')),
            ],
          ),
        );
      case 1:
        return _wrap(
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : null,
                        child: _imageFile == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.amber,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional for now)',
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                    ),
                    child: Text(
                      _dob == null
                          ? 'Select'
                          : _dob!.toIso8601String().split('T').first,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _next, child: const Text('Continue')),
              ],
            ),
          ),
        );
      case 2:
        return _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
              ),
              SwitchListTile(
                title: const Text('Merge guest data on login'),
                subtitle: const Text(
                  'Upload your local cart & favorites next time you sign in.',
                ),
                value: _mergeOnLogin,
                onChanged: (v) => setState(() => _mergeOnLogin = v),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => setState(() => _step++),
                      child: const Text('Review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      case 3:
      default:
        return _wrap(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                title: const Text('Name'),
                subtitle: Text(_nameCtrl.text.isEmpty ? '—' : _nameCtrl.text),
              ),
              ListTile(
                title: const Text('Phone'),
                subtitle: Text(_phoneCtrl.text.isEmpty ? '—' : _phoneCtrl.text),
              ),
              ListTile(
                title: const Text('DOB'),
                subtitle: Text(
                  _dob == null ? '—' : _dob!.toIso8601String().split('T').first,
                ),
              ),
              ListTile(
                title: const Text('Notifications'),
                subtitle: Text(_notifications ? 'On' : 'Off'),
              ),
              ListTile(
                title: const Text('Merge on Login'),
                subtitle: Text(_mergeOnLogin ? 'Enabled' : 'Disabled'),
              ),
              const Spacer(),
              if (_saving)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton(onPressed: _save, child: const Text('Finish')),
              const SizedBox(height: 8),
              TextButton(onPressed: _back, child: const Text('Edit')),
            ],
          ),
        );
    }
  }

  Widget _wrap(Widget child) => Padding(
    padding: const EdgeInsets.all(16),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    ),
  );
}
