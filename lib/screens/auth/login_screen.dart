import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/firebase_service.dart';
// import 'complete_profile_screen.dart'; // legacy screen kept for fallback (not used directly now)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import '../../utils/password_strength.dart';
import '../../theme/tokens.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  late TabController _tabController;
  bool _showPassword = false;
  double _pwdStrengthFrac = 0;
  String _pwdStrengthLabel = '';

  bool _googleConfigIssue = false;
  bool _googleConfigChecked = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _confirmPassCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _preflightGoogle();
  }

  Future<void> _preflightGoogle() async {
    // Only run in debug mode to avoid unnecessary calls in production.
    assert(() {
      () async {
        try {
          // A silent sign-in attempt will quickly fail with ApiException:10 if misconfigured.
          await GoogleSignIn(scopes: ['email']).signInSilently();
        } catch (e) {
          final lower = e.toString().toLowerCase();
          if (lower.contains('apiexception') && lower.contains('10')) {
            _googleConfigIssue = true;
          }
        } finally {
          if (mounted) setState(() => _googleConfigChecked = true);
        }
      }();
      return true;
    }());
  }

  Future<void> _submit(bool create) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;
      if (create) {
        cred = await auth.createUserWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
        final user = cred.user;
        final displayName =
            '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();
        if (displayName.isNotEmpty) {
          await user?.updateDisplayName(displayName);
        }
        // Initialize user doc with basic profile info (profileCompleted remains false until DOB & optional photo collected)
        final userDoc = FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid);
        await userDoc.set({
          'firstName': _firstNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'name': displayName,
          'phone': _phoneCtrl.text.trim(),
          'profileCompleted': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        cred = await auth.signInWithEmailAndPassword(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text.trim(),
        );
      }
      // Update global user reference.
      // ignore: avoid_print
      print('[LoginScreen] Auth success: ${cred.user?.uid}');
      // After any successful auth, decide if onboarding needed.
      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final completed = snap.data()?['profileCompleted'] == true;
      if (!completed && mounted) {
        // Replace stack with onboarding; when it pops return success to caller.
        await Navigator.pushReplacementNamed(context, '/secure-setup');
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email to reset password');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          appSnackBar('Password reset email sent', icon: Icons.mail_outline),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final googleUser = await GoogleSignIn(scopes: ['email']).signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      // Check if profile already completed
      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final completed = doc.data()?['profileCompleted'] == true;
      if (!completed && mounted) {
        await Navigator.pushReplacementNamed(context, '/secure-setup');
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) Navigator.pop(context, true);
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? e.code;
      final raw = msg.toLowerCase();
      if (raw.contains('signinwithidp') || raw.contains('identitytoolkit')) {
        msg =
            'Google sign-in blocked by project configuration. '
            'Fix steps: 1) Enable Google provider in Firebase Auth console. '
            '2) Relax API key restrictions to allow Identity Toolkit. '
            '3) Add SHA-1 & SHA-256 fingerprints in Firebase project settings. '
            '4) Download updated google-services.json & rebuild.';
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauth = OAuthProvider('apple.com');
      final oAuthCredential = oauth.credential(
        idToken: credential.identityToken,
        accessToken: credential.authorizationCode,
      );
      final cred = await FirebaseAuth.instance.signInWithCredential(
        oAuthCredential,
      );
      // On first sign-in, Apple may not provide name again; store if available.
      final uid = cred.user!.uid;
      final users = FirebaseFirestore.instance.collection('users');
      final doc = await users.doc(uid).get();
      final completed = doc.data()?['profileCompleted'] == true;
      if (!completed) {
        if (credential.givenName != null) {
          await cred.user!.updateDisplayName(
            '${credential.givenName} ${credential.familyName ?? ''}'.trim(),
          );
        }
        if (mounted) {
          await Navigator.pushReplacementNamed(context, '/secure-setup');
          if (!mounted) return;
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on SignInWithAppleAuthorizationException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Already on login screen; just rebuild state.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final gold =
        Theme.of(context).appBarTheme.iconTheme?.color ??
        const Color(0xFFE6B450);
    final user = FirebaseService.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        bottom: user == null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Sign Up'),
                ],
              )
            : null,
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Sign out',
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_googleConfigIssue && _googleConfigChecked)
              MaterialBanner(
                backgroundColor: Colors.red.shade700,
                content: const Text(
                  'Google Sign-In misconfigured (ApiException:10). Add SHA-1/SHA-256 to Firebase and re-download google-services.json.',
                  style: TextStyle(color: Colors.white),
                ),
                actions: [
                  TextButton(
                    onPressed: () => setState(() => _googleConfigIssue = false),
                    child: const Text(
                      'Dismiss',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            Expanded(
              child: user != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Signed in as ${user.email ?? user.uid}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildForm(false, gold),
                        _buildForm(true, gold),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool create, Color gold) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              create
                  ? 'Create an account to sync your cart & favorites across devices.'
                  : 'Log in to continue checkout and sync your data.',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            if (create) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                      validator: (v) {
                        if (!create) return null; // not visible otherwise
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      validator: (v) {
                        if (!create) return null;
                        if (v == null || v.trim().isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                validator: (v) {
                  if (!create) return null;
                  if (v == null || v.trim().isEmpty) return 'Phone required';
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length < 7) return 'Invalid phone';
                  return null;
                },
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              onChanged: (v) {
                final ps = evaluatePassword(v.trim());
                setState(() {
                  _pwdStrengthFrac = ps.fraction;
                  _pwdStrengthLabel = ps.label;
                });
              },
              validator: (v) {
                if (v == null) return 'Password required';
                final pwd = v.trim();
                if (pwd.length < 8 || pwd.length > 20) return '8-20 chars';
                if (!RegExp(r'[A-Z]').hasMatch(pwd)) return 'Add uppercase';
                if (!RegExp(r'[a-z]').hasMatch(pwd)) return 'Add lowercase';
                if (!RegExp(r'[0-9\W]').hasMatch(pwd))
                  return 'Add number or symbol';
                return null;
              },
            ),
            if (create) ...[
              const SizedBox(height: 6),
              _PasswordStrengthBar(
                fraction: _pwdStrengthFrac,
                label: _pwdStrengthLabel,
              ),
            ],
            if (create) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (v) {
                  if (!create) return null;
                  if (v == null || v.isEmpty) return 'Confirm password';
                  if (v != _passCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _sendPasswordReset,
                child: const Text('Forgot password?'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: () => _submit(create),
                child: Text(create ? 'Create Account' : 'Log In'),
              ),
            const SizedBox(height: 12),
            if (!create) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
                onPressed: _loading ? null : _googleSignIn,
              ),
              if (!create && (Platform.isIOS || Platform.isMacOS))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SignInWithAppleButton(
                    onPressed: () {
                      if (_loading) return;
                      _appleSignIn();
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final double fraction; // 0..1
  final String label;
  const _PasswordStrengthBar({required this.fraction, required this.label});

  Color _color(BuildContext context) {
    if (fraction >= 0.9) return Colors.greenAccent;
    if (fraction >= 0.7) return Colors.lightGreen;
    if (fraction >= 0.5) return Colors.amber;
    if (fraction >= 0.3) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction == 0 ? null : fraction.clamp(0, 1),
            minHeight: 6,
            backgroundColor: Colors.white12,
            color: _color(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label.isEmpty ? 'Password strength' : label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
