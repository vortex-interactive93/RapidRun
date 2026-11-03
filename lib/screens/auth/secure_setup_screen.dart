import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/log_service.dart';

/// Post-auth secure setup flow collecting phone (2FA), name, and optional photo.
/// Steps:
/// 0 = Phone Entry / Send Code (if phone not linked)
/// 1 = Verify SMS Code
/// 2 = Profile (name + photo)
/// 3 = Review & Finish
class SecureSetupScreen extends StatefulWidget {
  const SecureSetupScreen({super.key});

  @override
  State<SecureSetupScreen> createState() => _SecureSetupScreenState();
}

class _SecureSetupScreenState extends State<SecureSetupScreen> {
  int _step = 0;
  final _phoneCtrl = TextEditingController();
  final _smsCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  File? _imageFile;
  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  bool _saving = false;
  String? _error;
  // Resend cooldown
  static const _resendCooldown = Duration(seconds: 45);
  DateTime? _lastSend;
  Timer? _cooldownTimer;
  // Removed unused _skippedPhone flag.

  @override
  void initState() {
    super.initState();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_lastSend == null) return;
      if (_canResend()) {
        setState(() {}); // ensures UI re-enables
        return;
      }
      setState(() {});
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if ((user.phoneNumber ?? '').isNotEmpty) {
        _step = 2; // jump ahead directly to profile if phone already linked
      }
      if ((user.displayName ?? '').isNotEmpty) {
        _nameCtrl.text = user.displayName!;
      }
    }
    LogService.instance.log(
      'secure_setup start step=$_step',
      category: 'onboarding',
    );
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _smsCtrl.dispose();
    _nameCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.length < 8) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    if (!_canResend()) return; // ignore rapid taps during cooldown
    setState(() {
      _sending = true;
      _error = null;
    });
    LogService.instance.log(
      'onboarding phone_send attempt number=$raw',
      category: 'onboarding',
    );
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: raw,
      timeout: const Duration(seconds: 60),
      forceResendingToken: _resendToken,
      verificationCompleted: (cred) async {
        // Auto-retrieval
        try {
          final user = FirebaseAuth.instance.currentUser!;
          await user.linkWithCredential(cred).catchError((_) async {
            // If already linked (provider-already-linked) just sign in with cred to ensure association.
            return FirebaseAuth.instance.signInWithCredential(cred);
          });
          if (mounted) {
            setState(() {
              _step = 2;
            });
          }
          LogService.instance.log(
            'onboarding phone_auto_verified',
            category: 'onboarding',
          );
        } catch (e) {
          // ignore
        }
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _step = 1;
        });
        _lastSend = DateTime.now();
        LogService.instance.log('onboarding code_sent', category: 'onboarding');
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        LogService.instance.log(
          'onboarding code_auto_timeout',
          category: 'onboarding',
        );
      },
      verificationFailed: (e) {
        setState(() => _error = e.message ?? e.code);
        LogService.instance.log(
          'onboarding phone_failed ${e.code}',
          category: 'onboarding',
          error: e,
        );
      },
    );
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) {
      setState(() => _error = 'No verification in progress');
      return;
    }
    final code = _smsCtrl.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    LogService.instance.log(
      'onboarding code_verify attempt',
      category: 'onboarding',
    );
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      final user = FirebaseAuth.instance.currentUser!;
      await user.linkWithCredential(cred).catchError((_) async {
        return FirebaseAuth.instance.signInWithCredential(cred);
      });
      if (mounted) setState(() => _step = 2);
      LogService.instance.log(
        'onboarding code_verify success',
        category: 'onboarding',
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
      LogService.instance.log(
        'onboarding code_verify fail ${e.code}',
        category: 'onboarding',
        error: e,
      );
    } catch (e) {
      setState(() => _error = e.toString());
      LogService.instance.log(
        'onboarding code_verify exception',
        category: 'onboarding',
        error: e,
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
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

  Future<void> _saveProfile() async {
    if (_nameCtrl.text.trim().length < 2) {
      setState(() => _error = 'Enter your name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    LogService.instance.log(
      'onboarding profile_save attempt',
      category: 'onboarding',
    );
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? photoUrl = user.photoURL;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref('user_photos/${user.uid}.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }
      if ((user.displayName ?? '').isEmpty) {
        await user.updateDisplayName(_nameCtrl.text.trim());
      }
      final phone = user.phoneNumber ?? _phoneCtrl.text.trim();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': phone,
        'phoneVerified': (user.phoneNumber ?? '').isNotEmpty,
        'photoUrl': photoUrl,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      LogService.instance.log(
        'onboarding profile_save success',
        category: 'onboarding',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
      LogService.instance.log(
        'onboarding profile_save fail',
        category: 'onboarding',
        error: e,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _nextFromProfile() {
    setState(() => _step = 3);
    LogService.instance.log('onboarding review_enter', category: 'onboarding');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Setup'),
        leading: _step == 0 || _step == 3
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    setState(() => _step = (_step - 1).clamp(0, 3)),
              ),
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
        return _wrap(_buildPhoneEntry());
      case 1:
        return _wrap(_buildVerify());
      case 2:
        return _wrap(_buildProfile());
      case 3:
      default:
        return _wrap(_buildReview());
    }
  }

  Widget _buildPhoneEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Verify your phone',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          decoration: const InputDecoration(labelText: 'Phone Number'),
          keyboardType: TextInputType.phone,
        ),
        if (_error != null) _errorText(),
        const Spacer(),
        _sending
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _sendCode,
                child: const Text('Send Code'),
              ),
        if (_lastSend != null && !_canResend())
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'You can resend a code in ${_remainingSeconds()}s',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildVerify() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Enter SMS Code',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _smsCtrl,
          decoration: const InputDecoration(labelText: '6-digit Code'),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        if (_error != null) _errorText(),
        const Spacer(),
        _verifying
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _verifyCode,
                child: const Text('Verify'),
              ),
        TextButton(
          onPressed: _sending || !_canResend() ? null : _sendCode,
          child: Text(
            _canResend() ? 'Resend Code' : 'Resend in ${_remainingSeconds()}s',
          ),
        ),
      ],
    );
  }

  Widget _buildProfile() {
    return SingleChildScrollView(
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
          if (_error != null) _errorText(),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _nextFromProfile,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: const Text('Name'),
          subtitle: Text(_nameCtrl.text.isEmpty ? '—' : _nameCtrl.text),
        ),
        ListTile(
          title: const Text('Phone'),
          subtitle: Text(_linkedPhoneOrPending()),
        ),
        ListTile(
          title: const Text('Photo'),
          subtitle: Text(_imageFile == null ? 'Not set' : 'Selected'),
        ),
        if (_error != null) _errorText(),
        const Spacer(),
        _saving
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Finish'),
              ),
        TextButton(
          onPressed: () => setState(() => _step = 2),
          child: const Text('Edit'),
        ),
      ],
    );
  }

  String _linkedPhoneOrPending() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
      return user.phoneNumber!;
    return _phoneCtrl.text.isEmpty
        ? 'Not verified'
        : '${_phoneCtrl.text} (pending)';
  }

  Widget _errorText() => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
  );

  Widget _wrap(Widget child) => Padding(
    padding: const EdgeInsets.all(16),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    ),
  );

  bool _canResend() {
    if (_lastSend == null) return true;
    return DateTime.now().difference(_lastSend!) >= _resendCooldown;
  }

  int _remainingSeconds() {
    if (_lastSend == null) return 0;
    final diff = DateTime.now().difference(_lastSend!);
    final remaining = _resendCooldown - diff;
    return remaining.inSeconds.clamp(0, 999);
  }
}
