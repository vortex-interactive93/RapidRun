import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// Screen shown immediately after account creation / first provider sign-in
/// to collect essential profile details.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DateTime? _dob;
  File? _imageFile;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: initial,
      helpText: 'Select Date of Birth',
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      setState(() {
        _error = 'Please select your date of birth';
      });
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
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }
      final data = {
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dob': _dob != null ? Timestamp.fromDate(_dob!) : null,
        'photoUrl': photoUrl,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }..removeWhere((k, v) => v == null);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
      if (mounted) {
        Navigator.of(
          context,
        ).pop(true); // return to previous (login) which will pop again
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFE6B450);
    return Scaffold(
      appBar: AppBar(title: const Text('Complete Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: gold.withValues(alpha: 0.2),
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : null,
                        child: _imageFile == null
                            ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white70,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _pickImage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: gold,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8),
                            child: const Icon(
                              Icons.edit,
                              size: 20,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Enter your name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone required';
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 7) return 'Invalid phone';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDob,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      errorText:
                          _error == 'Please select your date of birth' &&
                              _dob == null
                          ? _error
                          : null,
                    ),
                    child: Text(
                      _dob == null
                          ? 'Tap to select'
                          : DateFormat.yMMMMd().format(_dob!),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save & Continue'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
