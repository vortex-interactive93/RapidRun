import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

/// Screen to view & manage personal details: email, phone, verification & password update.
/// NOTE: Phone/SMS verification requires Firebase phone auth setup (not implemented fully here);
/// The current implementation stubs confirmation code sending for demonstration.
class PersonalDetailsScreen extends StatefulWidget {
  const PersonalDetailsScreen({super.key});

  @override
  State<PersonalDetailsScreen> createState() => _PersonalDetailsScreenState();
}

class _PersonalDetailsScreenState extends State<PersonalDetailsScreen> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmNewPassCtrl = TextEditingController();
  final _currentPassCtrl = TextEditingController();
  final _mfaCodeCtrl = TextEditingController();
  bool _sendingCode = false;
  bool _verifying = false;
  bool _changingPassword = false;
  String? _status;
  String? _error;
  String? _verificationId; // phone auth verificationId
  int? _resendToken;
  bool _phoneVerified = false;
  bool _reauthOk = false; // track recent reauth for direct password change
  DateTime? _reauthExpiry;
  String? _pendingPhone;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  String? _mfaVerificationId;
  int? _mfaResendToken;
  bool _mfaEnrolling = false;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _phoneCtrl.text = user?.phoneNumber ?? '';
    _phoneVerified = user?.phoneNumber != null;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmNewPassCtrl.dispose();
    _currentPassCtrl.dispose();
    _mfaCodeCtrl.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.sendEmailVerification();
      setState(() => _status = 'Verification email sent to ${user.email}');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _sendPhoneCode() async {
    final raw = _phoneCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter phone number');
      return;
    }
    if (_phoneVerified &&
        FirebaseAuth.instance.currentUser?.phoneNumber != raw) {
      _phoneVerified =
          false; // resetting verified state until new number confirmed
    }
    _pendingPhone = raw;
    await _persistPendingPhone(raw);
    setState(() {
      _sendingCode = true;
      _error = null;
      _status = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: raw,
      forceResendingToken: _resendToken,
      verificationCompleted: (cred) async {
        try {
          await FirebaseAuth.instance.currentUser?.updatePhoneNumber(cred);
          await _markPhoneVerified(raw);
          setState(() {
            _status = 'Phone automatically verified';
            _phoneVerified = true;
          });
        } catch (e) {
          setState(() => _error = e.toString());
        }
      },
      verificationFailed: (e) {
        setState(() {
          _error = e.message;
          _sendingCode = false;
        });
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          _sendingCode = false;
          _status = 'Code sent';
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (_verificationId == null) {
          setState(() {
            _verificationId = verificationId;
          });
        }
      },
      timeout: const Duration(seconds: 60),
    );
    _startCooldown();
  }

  Future<void> _verifyPhoneCode() async {
    if (_verificationId == null) return;
    final sms = _codeCtrl.text.trim();
    if (sms.length < 4) {
      setState(() => _error = 'Enter code');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
      _status = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: sms,
      );
      await FirebaseAuth.instance.currentUser?.updatePhoneNumber(cred);
      await _markPhoneVerified(_phoneCtrl.text.trim());
      setState(() {
        _verifying = false;
        _status = 'Phone verified';
        _phoneVerified = true;
        _pendingPhone = null;
      });
    } catch (e) {
      setState(() {
        _verifying = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _markPhoneVerified(String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'phoneVerified': true,
      'phone': phone,
      'phonePending': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _persistPendingPhone(String phone) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'phonePending': phone,
      'phoneVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() {
      _cooldown = 30;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() {
          _cooldown = 0;
        });
      } else {
        setState(() {
          _cooldown--;
        });
      }
    });
  }

  Future<void> _initiatePasswordChange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!(user.emailVerified || user.phoneNumber != null)) {
      setState(() => _error = 'Verify email or phone first.');
      return;
    }
    // For email accounts: send password reset email as confirmation code path.
    if (user.email != null) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
        setState(
          () => _status =
              'Password reset email sent. Follow link to set new password.',
        );
      } catch (e) {
        setState(() => _error = e.toString());
      }
    } else {
      setState(
        () => _error = 'Direct password change not available without email.',
      );
    }
  }

  Future<void> _reauthenticate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      if (user.email != null) {
        final pwd = _currentPassCtrl.text.trim();
        if (pwd.isEmpty) {
          setState(() => _error = 'Enter current password');
          return;
        }
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: pwd,
        );
        await user.reauthenticateWithCredential(cred);
        setState(() {
          _reauthOk = true;
          _reauthExpiry = DateTime.now().add(const Duration(minutes: 5));
          _status = 'Re-authenticated';
        });
      } else if (user.phoneNumber != null) {
        // For phone users you'd trigger a resend code and link result; simplified here.
        await user.reload();
        setState(() {
          _reauthOk = true;
          _reauthExpiry = DateTime.now().add(const Duration(minutes: 5));
          _status = 'Re-authenticated';
        });
      } else {
        setState(() => _error = 'No reauth method available');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _changePasswordDirect() async {
    if (!_reauthOk) {
      setState(() => _error = 'Re-authenticate first');
      return;
    }
    if (_reauthExpiry != null && DateTime.now().isAfter(_reauthExpiry!)) {
      setState(() {
        _reauthOk = false;
        _error = 'Re-auth expired';
      });
      return;
    }
    // Optional direct in-app change when reauthenticated (not fully implemented). Validate complexity.
    final pwd = _newPassCtrl.text.trim();
    final confirm = _confirmNewPassCtrl.text.trim();
    String? err;
    if (pwd.length < 8 || pwd.length > 20) err = 'Password 8-20 chars.';
    if (err == null && !RegExp(r'[A-Z]').hasMatch(pwd)) err = 'Add uppercase';
    if (err == null && !RegExp(r'[a-z]').hasMatch(pwd)) err = 'Add lowercase';
    if (err == null && !RegExp(r'[0-9\W]').hasMatch(pwd))
      err = 'Add number/symbol';
    if (err == null && pwd != confirm) err = 'Passwords do not match';
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _changingPassword = true;
      _error = null;
      _status = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.updatePassword(pwd);
      setState(() => _status = 'Password updated');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final emailVerified = user?.emailVerified ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _status!,
                style: const TextStyle(color: Colors.greenAccent),
              ),
            ),
          ListTile(
            title: const Text('Email'),
            subtitle: Text(user?.email ?? 'None'),
            trailing: emailVerified
                ? const Chip(label: Text('Verified'))
                : TextButton(
                    onPressed: _sendEmailVerification,
                    child: const Text('Verify'),
                  ),
          ),
          const Divider(),
          TextField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              suffixIcon: _phoneVerified
                  ? const Icon(Icons.verified, color: Colors.greenAccent)
                  : (_pendingPhone != null
                        ? const Icon(
                            Icons.hourglass_bottom,
                            color: Colors.orangeAccent,
                          )
                        : null),
            ),
            keyboardType: TextInputType.phone,
            onChanged: (v) {
              _pendingPhone = v.trim();
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: (_sendingCode || _cooldown > 0)
                    ? null
                    : _sendPhoneCode,
                child: _sendingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _cooldown > 0 ? 'Resend (${_cooldown})' : 'Send Code',
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CodeBoxes(
                  controller: _codeCtrl,
                  length: 6,
                  onCompleted: () {
                    if (_verificationId != null && !_verifying) {
                      _verifyPhoneCode();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: (_verificationId == null || _verifying)
                    ? null
                    : _verifyPhoneCode,
                child: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_phoneVerified) ...[
            const Text(
              'Multi-Factor Authentication (SMS)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Enroll your phone for optional 2-step verification.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_mfaVerificationId == null)
              ElevatedButton(
                onPressed: _mfaEnrolling ? null : _startMfaEnrollment,
                child: _mfaEnrolling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start Enrollment'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _CodeBoxes(
                      controller: _mfaCodeCtrl,
                      length: 6,
                      onCompleted: () {
                        if (!_mfaEnrolling) _confirmMfaEnrollment();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _mfaEnrolling ? null : _confirmMfaEnrollment,
                    child: _mfaEnrolling
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Enroll'),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
          const Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'To change your password we first send a confirmation code email (or use direct change below if reauthenticated).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _initiatePasswordChange,
            child: const Text('Send Password Reset Email'),
          ),
          ExpansionTile(
            title: const Text('Advanced: Change Password Here'),
            subtitle: !_reauthOk ? const Text('Re-auth required') : null,
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _reauthOk ? null : _reauthenticate,
                    child: const Text('Re-Auth'),
                  ),
                  const SizedBox(width: 12),
                  if (_reauthOk) const Chip(label: Text('Ready')),
                ],
              ),
              if (!_reauthOk)
                TextField(
                  controller: _currentPassCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                  ),
                  obscureText: true,
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _newPassCtrl,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              TextField(
                controller: _confirmNewPassCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _changingPassword ? null : _changePasswordDirect,
                  child: _changingPassword
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update Password'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startMfaEnrollment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.phoneNumber == null) return;
    setState(() {
      _mfaEnrolling = true;
      _error = null;
      _status = null;
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: user.phoneNumber!,
      forceResendingToken: _mfaResendToken,
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        setState(() {
          _error = e.message;
          _mfaEnrolling = false;
        });
      },
      codeSent: (id, token) {
        setState(() {
          _mfaVerificationId = id;
          _mfaResendToken = token;
          _mfaEnrolling = false;
          _status = 'MFA code sent';
        });
      },
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<void> _confirmMfaEnrollment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _mfaVerificationId == null) return;
    final code = _mfaCodeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter MFA code');
      return;
    }
    setState(() {
      _mfaEnrolling = true;
      _error = null;
      _status = null;
    });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _mfaVerificationId!,
        smsCode: code,
      );
      final assertion = PhoneMultiFactorGenerator.getAssertion(cred);
      await user.multiFactor.enroll(assertion, displayName: 'Primary phone');
      setState(() {
        _mfaEnrolling = false;
        _status = 'SMS 2FA enrolled';
        _mfaVerificationId = null;
        _mfaCodeCtrl.clear();
      });
    } catch (e) {
      setState(() {
        _mfaEnrolling = false;
        _error = e.toString();
      });
    }
  }
}

/// Segmented 1-digit per box code entry widget.
class _CodeBoxes extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final VoidCallback? onCompleted;
  const _CodeBoxes({
    required this.controller,
    this.length = 6,
    this.onCompleted,
  });

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  late List<FocusNode> _nodes;
  @override
  void initState() {
    super.initState();
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _update() {
    final txt = widget.controller.text;
    if (txt.length == widget.length) {
      widget.onCompleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(widget.length, (i) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 4),
            child: TextField(
              focusNode: _nodes[i],
              textAlign: TextAlign.center,
              maxLength: 1,
              decoration: const InputDecoration(counterText: ''),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final current = widget.controller.text;
                final b = StringBuffer();
                for (int j = 0; j < widget.length; j++) {
                  if (j == i) {
                    b.write(v.isEmpty ? '' : v);
                  } else if (j < current.length) {
                    b.write(current[j]);
                  }
                }
                widget.controller.text = b.toString();
                if (v.isNotEmpty && i < widget.length - 1) {
                  _nodes[i + 1].requestFocus();
                }
                _update();
              },
            ),
          ),
        );
      }),
    );
  }
}
