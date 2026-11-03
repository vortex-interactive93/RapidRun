// File: rapidrun_driver/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'screens/driver_home_screen.dart';
import 'theme/driver_theme_extension.dart';
import 'theme/design_tokens.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark();
    final driverDesign = DriverDesign.fallback();
    return MaterialApp(
      title: 'RapidRun Driver',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: DesignTokens.primary,
          secondary: DesignTokens.secondary,
        ),
        scaffoldBackgroundColor: DesignTokens.surfaceBase,
        cardColor: DesignTokens.surfaceElevated,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1B1B1B)),
        textTheme: base.textTheme.copyWith(
          titleMedium: base.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: base.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        extensions: [DriverTheme.fallback, driverDesign],
      ),
      navigatorKey: navigatorKey,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const _SignInScreen();
        return _DriverGate(
          uid: user.uid,
          onSignOut: () => FirebaseAuth.instance.signOut(),
        );
      },
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen();
  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  bool _busy = false;

  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final auth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _anonymous() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5A93C).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Color(0xFFE5A93C),
                    size: 52,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'RapidRun Driver',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to access driver dispatch',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE5A93C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.login),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy ? null : _anonymous,
                    child: const Text(
                      'Debug: Anonymous Sign-In',
                      style: TextStyle(color: Color(0xFFE5A93C)),
                    ),
                  ),
                ],
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: Color(0xFFE5A93C)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverGate extends StatelessWidget {
  final String uid;
  final VoidCallback onSignOut;
  const _DriverGate({required this.uid, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('drivers').doc(uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildObsidianSkeleton('HYDRATING FLEET PROFILE...');
        }

        if (!snap.hasData || !snap.data!.exists) {
          final user = FirebaseAuth.instance.currentUser;
          final email = user?.email ?? '';
          final name = user?.displayName ??
              (email.contains('@') ? email.split('@').first : 'Driver');

          // Auto-provision missing driver profile in background
          docRef.set({
            'active': true,
            'name': name,
            'email': email,
            'online': false,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'rating': 5.0,
            'totalDeliveriesCompleted': 0,
            'todayEarnings': 0.0,
          }, SetOptions(merge: true));

          return _buildObsidianSkeleton('PROVISIONING FLEET PROFILE...');
        }

        final data = snap.data!.data() ?? {};
        final active = data['active'] != false;

        if (!active) {
          return Scaffold(
            backgroundColor: const Color(0xFF0C0C0E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF14171D),
              title: const Text('Driver Profile Inactive'),
              actions: [
                IconButton(
                  onPressed: onSignOut,
                  tooltip: 'Sign Out',
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            body: const Center(
              child: Text(
                'Your driver profile is currently inactive.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return DriverHomeScreen(driverId: uid);
      },
    );
  }

  Widget _buildObsidianSkeleton(String label) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE5A93C).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: Color(0xFFE5A93C),
                size: 52,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Color(0xFFE5A93C)),
            const SizedBox(height: 20),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE5A93C),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
